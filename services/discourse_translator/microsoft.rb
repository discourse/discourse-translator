# frozen_string_literal: true

require_relative 'base'

module DiscourseTranslator
  class Microsoft < Base
    DATA_URI = "https://datamarket.accesscontrol.windows.net/v2/OAuth2-13"
    SCOPE_URI = "api.cognitive.microsofttranslator.com"
    GRANT_TYPE = "client_credentials"
    TRANSLATE_URI = "https://api.cognitive.microsofttranslator.com/translate"
    DETECT_URI = "https://api.cognitive.microsofttranslator.com/detect"
    ISSUE_TOKEN_URI = "https://api.cognitive.microsoft.com/sts/v1.0/issueToken"

    LENGTH_LIMIT = 10_000

    SUPPORTED_LANG = {
      en: 'en',
      en_US: 'en',
      en_GB: 'en',
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
      vi: 'vi',
      zh_CN: 'zh-Hans',
      zh_TW: 'zh-Hant',
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
      existing_token = Discourse.redis.get(cache_key)

      if existing_token
        existing_token
      elsif SiteSetting.translator_azure_subscription_key.present?
        url = "#{DiscourseTranslator::Microsoft::ISSUE_TOKEN_URI}?Subscription-Key=#{SiteSetting.translator_azure_subscription_key}"

        # Congitive Service's multi-service resource requires a region to be specified
        # https://docs.microsoft.com/en-us/azure/cognitive-services/translator/reference/v3-0-reference#authenticating-with-an-access-token
        if SiteSetting.translator_azure_region != 'global'
          uri = URI.parse(url)
          uri.host = "#{SiteSetting.translator_azure_region}.#{uri.host}"
          url = uri.to_s
        end

        response = Excon.post(url)

        if response.status == 200 && (response_body = response.body).present?
          Discourse.redis.setex(cache_key, 8.minutes.to_i, response_body)
          response_body
        elsif response.body.blank?
          raise TranslatorError.new(I18n.t("translator.microsoft.missing_token"))
        else
          # The possible response isn't well documented in Microsoft's API so
          # it might break from time to time.
          error = JSON.parse(response.body)["error"]
          raise TranslatorError.new("#{error['code']}: #{error['message']}")
        end
      end
    end

    def self.detect(post)
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||= begin
        text = post.raw.truncate(LENGTH_LIMIT, omission: nil)

        body = [
          { "Text" => text }
        ].to_json

        uri = URI(DETECT_URI)
        uri.query = URI.encode_www_form(self.default_query)

        response_body = result(
          uri.to_s,
          body,
          default_headers
        )

        response_body.first["language"]
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
        query = default_query.merge(
          "from" => detected_lang,
          "to" => locale,
          "textType" => "html"
        )

        body = [
          { "Text" => post.cooked }
        ].to_json

        uri = URI(TRANSLATE_URI)
        uri.query = URI.encode_www_form(query)

        response_body = result(uri.to_s, body, default_headers)
        response_body.first["translations"].first["text"]
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
      response = post(uri, body, headers)
      response_body = JSON.parse(response.body)

      if response.status != 200
        raise TranslatorError.new(response_body)
      else
        response_body
      end
    end

    def self.default_headers
      {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json'
      }
    end

    def self.default_query
      {
        "api-version" => "3.0"
      }
    end
  end
end
