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
end
