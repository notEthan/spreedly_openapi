require 'scorpio'
require 'spreedly_openapi'

module SpreedlyOpenAPI
  Document = Scorpio::OpenAPI::Document.from_instance(::YAML.load(SPREEDLY_OPENAPI3_YML))

  # GENERATED (relying on activesupport) vaguely like
  # puts SpreedlyOpenAPI::Document.components.schemas.select { |k,v| ['object', nil].include?(v['type']) }.keys.map { |k| "#{k.camelize} = ...('#{k}')" }

  Errors            = Document.components.schemas['errors'].jsi_schema_module
  TransactionWrapper = Document.components.schemas['transaction_wrapper'].jsi_schema_module
  Transaction        = Document.components.schemas['transaction'].jsi_schema_module
  Gateway             = Document.components.schemas['gateway'].jsi_schema_module
  GatewayCreateRequest = Document.components.schemas['gateway_create_request'].jsi_schema_module
  GatewayUpdateRequest  = Document.components.schemas['gateway_update_request'].jsi_schema_module
  ReceiverOption        = Document.components.schemas['receiver_option'].jsi_schema_module
  ReceiverCreateRequest = Document.components.schemas['receiver_create_request'].jsi_schema_module
  ReceiverCredentials  = Document.components.schemas['receiver_credentials'].jsi_schema_module
  Receiver            = Document.components.schemas['receiver'].jsi_schema_module
  PaymentMethod        = Document.components.schemas['payment_method'].jsi_schema_module
  PassInCreditCard      = Document.components.schemas['pass_in_credit_card'].jsi_schema_module
  PassInBankAccount      = Document.components.schemas['pass_in_bank_account'].jsi_schema_module
  PassInAndroidPay        = Document.components.schemas['pass_in_android_pay'].jsi_schema_module
  PassInGooglePay          = Document.components.schemas['pass_in_google_pay'].jsi_schema_module
  PassInApplePay            = Document.components.schemas['pass_in_apple_pay'].jsi_schema_module
  PurchaseTransactionRequest = Document.components.schemas['purchase_transaction_request'].jsi_schema_module
  Certificate               = Document.components.schemas['certificate'].jsi_schema_module

  # @param request [Scorpio::Request]
  # @param resource_name [String]
  # @yield record [Object]
  # @return [Enumerator, nil]
  def self.each_resource(request, resource_name, &block)
    return to_enum(__method__, request, resource_name) unless block_given?

    next_page = -> (last_page_ur) do
      records = last_page_ur.response.body_object[resource_name]
      if records.respond_to?(:to_ary) && !records.empty? && records.last.respond_to?(:to_hash)
        since_token = records.last['token']
      end
      request = last_page_ur.scorpio_request.dup
      if since_token
        request.query_params = {'since_token' => since_token}
        request.run_ur
      else
        nil
      end
    end
    request.each_page_ur(next_page: next_page) do |page_ur|
      records = page_ur.response.body_object[resource_name]
      if records.respond_to?(:to_ary)
        records.each(&block)
      end
    end
    nil
  end

  module Receiver
    # @return [SpreedlyOpenAPI::Receiver]
    def self.find_or_create(receiver_type: , hostnames: , credentials: , **request_config)
      find(receiver_type: receiver_type, hostnames: hostnames, credentials: credentials, **request_config) ||
        create(receiver_type: receiver_type, hostnames: hostnames, credentials: credentials, **request_config)
    end

    # @return [SpreedlyOpenAPI::Receiver]
    def self.find(receiver_type: , hostnames: , credentials: , **request_config)
      list = SpreedlyOpenAPI::Document.operations['receivers.list'].build_request(request_config)
      SpreedlyOpenAPI.each_resource(list, 'receivers').detect do |receiver|
        credentials_set, receiver_credentials_set = [credentials, receiver.credentials].map do |credentialary|
          JSI::Typelike.as_json(credentialary).map do |credential|
            # spreedly stringifies this boolean value
            credential = credential.merge('safe' => credential['safe'].to_s)
            credential['safe'] == 'true' ? credential : credential.reject { |k, _| k == 'value' }
          end.to_set
        end
        receiver.receiver_type == receiver_type &&
          receiver.hostnames == hostnames &&
          credentials_set == receiver_credentials_set
      end
    end

    # @return [SpreedlyOpenAPI::Receiver]
    def self.create(receiver_type: , hostnames: , credentials: , **request_config)
      SpreedlyOpenAPI::Document.operations['receivers.create'].run(request_config) do |req|
        req.body_object = SpreedlyOpenAPI::ReceiverCreateRequest.new({
          'receiver' => {
            'receiver_type' => receiver_type,
            'hostnames' => hostnames,
            'credentials' => credentials,
          }
        })
        req.body_object.validate!
      end.receiver
    end

    # @param payment_method_token [String]
    # @param scorpio_request [Scorpio::Request]
    # @return [Object]
    def deliver(payment_method_token: , scorpio_request: , **request_config)
      begin
        delivery = SpreedlyOpenAPI::Document.operations['receivers.deliver'].run(
          path_params: {'receiver_token' => self.token},
          body_object: {
            'delivery' => {
              'continue_caching' => nil,
              'payment_method_token' => payment_method_token,
              'url' => scorpio_request.url.to_s,
              'request_method' => scorpio_request.http_method.to_s.upcase,
              'headers' => scorpio_request.headers.map { |k, v| %Q(#{k}: #{v}) }.join("\n"),
              'body' => scorpio_request.body,
              'encode_response' => false,
            }
          },
          **request_config,
        )
      rescue Scorpio::HTTPErrors::UnprocessableEntity422Error => e
        if e.response_object.is_a?(SpreedlyOpenAPI::TransactionWrapper)
          delivery = e.response_object
        else
          raise
        end
      end
      # dumb thing to get Net::HTTP to parse the raw headers spreedly gives us
      headers = begin
        require 'net/http'
        response_str = "HTTP 000\r\n" + delivery.transaction.response['headers']
        net_response = Net::HTTPResponse.read_new(Net::BufferedIO.new(StringIO.new(response_str)))
        net_response.each_header.map { |k, v| {k => v} }.inject({}, &:update)
      end

      ur = Scorpio::Ur.new({
        'response' => {
          'status' => delivery.transaction.response['status'],
          'headers' => headers,
          'body' => delivery.transaction.response['body'],
        }
      })
      ur.scorpio_request = scorpio_request
      ur.raise_on_http_error
      ur.response.body_object
    end
  end
end
