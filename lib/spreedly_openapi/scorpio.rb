require 'scorpio'
require 'spreedly_openapi'

module SpreedlyOpenAPI
  Document = Scorpio::OpenAPI::V3::Document.new(::YAML.load(SPREEDLY_OPENAPI3_YML))

  # GENERATED (relying on activesupport) vaguely like
  # puts SpreedlyOpenAPI::Document.components.schemas.select { |k,v| ['object', nil].include?(v['type']) }.keys.map { |k| "#{k.camelize} = ...('#{k}')" }

  Errors            = JSI.class_for_schema(Document.components.schemas['errors'])
  TransactionWrapper = JSI.class_for_schema(Document.components.schemas['transaction_wrapper'])
  Transaction        = JSI.class_for_schema(Document.components.schemas['transaction'])
  Gateway             = JSI.class_for_schema(Document.components.schemas['gateway'])
  GatewayCreateRequest = JSI.class_for_schema(Document.components.schemas['gateway_create_request'])
  GatewayUpdateRequest  = JSI.class_for_schema(Document.components.schemas['gateway_update_request'])
  ReceiverOption        = JSI.class_for_schema(Document.components.schemas['receiver_option'])
  ReceiverCreateRequest = JSI.class_for_schema(Document.components.schemas['receiver_create_request'])
  ReceiverCredentials  = JSI.class_for_schema(Document.components.schemas['receiver_credentials'])
  Receiver            = JSI.class_for_schema(Document.components.schemas['receiver'])
  PaymentMethod        = JSI.class_for_schema(Document.components.schemas['payment_method'])
  PassInCreditCard      = JSI.class_for_schema(Document.components.schemas['pass_in_credit_card'])
  PassInBankAccount      = JSI.class_for_schema(Document.components.schemas['pass_in_bank_account'])
  PassInAndroidPay        = JSI.class_for_schema(Document.components.schemas['pass_in_android_pay'])
  PassInGooglePay          = JSI.class_for_schema(Document.components.schemas['pass_in_google_pay'])
  PassInApplePay            = JSI.class_for_schema(Document.components.schemas['pass_in_apple_pay'])
  PurchaseTransactionRequest = JSI.class_for_schema(Document.components.schemas['purchase_transaction_request'])
  Certificate               = JSI.class_for_schema(Document.components.schemas['certificate'])

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

  class Receiver
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
