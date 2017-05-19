require_relative 'base'

module DiscourseTranslator
  class Microsoft < Base
    DATA_URI = "https://datamarket.accesscontrol.windows.net/v2/OAuth2-13".freeze
    SCOPE_URI = "http://api.microsofttranslator.com".freeze
    GRANT_TYPE = "client_credentials".freeze
    TRANSLATE_URI = "http://api.microsofttranslator.com/V2/Http.svc/GetTranslationsArray".freeze
    DETECT_URI = "https://api.microsofttranslator.com/V2/Http.svc/DetectArray".freeze

    ISSUE_TOKEN_URI = "https://api.cognitive.microsoft.com/sts/v1.0/issueToken".freeze

    LENGTH_LIMIT = 10240.freeze

    SUPPORTED_LANG = {
      en: 'en',
      bs_BA: 'bs-Latn',
      cs: 'cs',
      da: 'da',
      de: 'de',
      ar: 'ar',
      es: 'es',
      fi: 'fi',
      fr: 'fr',
      he: 'he',
      id: 'id',
      it: 'it',
      ja: 'ja',
      ko: 'ko',
      nl: 'nl',
      pt: 'pt',
      ro: 'ro',
      ru: 'ru',
      sv: 'sv',
      uk: 'uk',
      zh_CN: 'zh-CHS',
      zh_TW: 'zh-CHT',
      tr_TR: 'tr',
      te: nil,
      sq: nil,
      pt_BR: 'pt',
      pl_PL: 'pl',
      no_NO: 'no',
      fa_IR: 'fa'
    }

    def self.access_token_key
      "microsoft-translator"
    end

    def self.access_token
      existing_token = $redis.get(cache_key)

      if existing_token
        return existing_token
      else
        if !SiteSetting.translator_azure_subscription_key.blank?
          response = Excon.post("#{ISSUE_TOKEN_URI}?Subscription-Key=#{SiteSetting.translator_azure_subscription_key}")

          if response.status == 200
            token = response.body
            $redis.setex(cache_key, 8.minutes.to_i, token)
            token
          else
            body = JSON.parse(response.body)
            raise TranslatorError.new("#{body['statusCode']}: #{body['message']}")
          end
        end
      end
    end

    def self.detect(post)
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||= begin
        text = CGI.escapeHTML(post.raw.truncate(LENGTH_LIMIT))

        body = <<-XML.strip_heredoc
        <ArrayOfstring xmlns="http://schemas.microsoft.com/2003/10/Serialization/Arrays" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
          <string>#{text}</string>
        </ArrayOfstring>
        XML

        xml_doc = result(DETECT_URI, body, default_headers.merge({ 'Content-Type' => 'text/xml' }))
        Nokogiri::XML(xml_doc).remove_namespaces!.xpath("//string").text
      end
    end

    def self.translate(post)
      detected_lang = detect(post)

      if !SUPPORTED_LANG.keys.include?(detected_lang.to_sym) &&
         !SUPPORTED_LANG.values.include?(detected_lang.to_s)

        raise TranslatorError.new(I18n.t('translator.failed'))
      end

      raise TranslatorError.new(I18n.t('translator.too_long')) if post.cooked.length > LENGTH_LIMIT

      translated_text = from_custom_fields(post) do
        body = <<-XML.strip_heredoc
        <GetTranslationsArrayRequest>
          <AppId></AppId>
          <From>#{detected_lang}</From>
          <Options>
            <ContentType xmlns="http://schemas.datacontract.org/2004/07/Microsoft.MT.Web.Service.V2">text/html</ContentType>
          </Options>
          <Texts>
            <string xmlns="http://schemas.microsoft.com/2003/10/Serialization/Arrays">#{CGI.escapeHTML(post.cooked)}</string>
          </Texts>
          <To>#{locale}</To>
          <MaxTranslations>1</MaxTranslations>
        </GetTranslationsArrayRequest>
        XML

        xml_doc = result(TRANSLATE_URI, body, default_headers.merge({ 'Content-Type' => 'text/xml' }))
        Nokogiri::XML(xml_doc).remove_namespaces!.xpath("//TranslatedText").text
      end

      [detected_lang, translated_text]
    end

    private

    def self.locale
      SUPPORTED_LANG[I18n.locale] || (raise I18n.t("translator.not_supported"))
    end

    def self.post(uri, body, headers = {})
      Excon.post(uri, body: body, headers: headers)
    end

    def self.result(uri, body, headers)
      response  = post(uri, body, headers)
      response_body = response.body

      if response.status != 200
        raise TranslatorError.new(Nokogiri::XML(response_body).text)
      else
        response_body
      end
    end

    def self.default_headers
      { 'Authorization' => "Bearer #{access_token}" }
    end
  end
end
