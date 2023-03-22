# frozen_string_literal: true

require_relative "base"

module DiscourseTranslator
  class Microsoft < Base
    TRANSLATE_URI = "https://api.cognitive.microsofttranslator.com/translate"
    DETECT_URI = "https://api.cognitive.microsofttranslator.com/detect"
    CUSTOM_URI_SUFFIX = "cognitiveservices.azure.com/translator/text/v3.0"
    LENGTH_LIMIT = 50_000

    # Hash which maps Discourse's locale code to Microsoft Translator's language code found in
    # https://docs.microsoft.com/en-us/azure/cognitive-services/translator/language-support
    # Format: Discourse Language Code: Azure Language Code
    SUPPORTED_LANG_MAPPING = {
      af: "af",
      ar: "ar",
      az: "az",
      bg: "bg",
      bn: "bn",
      bo: "bo",
      bs_BA: "bs",
      ca: "ca",
      cs: "cs",
      cy: "cy",
      da: "da",
      de: "de",
      el: "el",
      en: "en",
      en_GB: "en",
      en_US: "en",
      es: "es",
      et: "et",
      eu: "eu",
      fa_IR: "fa",
      fi: "fi",
      fr: "fr",
      gl: "gl",
      he: "he",
      hi: "hi",
      hr: "hr",
      hu: "hu",
      hy: "hy",
      id: "id",
      is: "is",
      it: "it",
      ja: "ja",
      ka: "ka",
      kk: "kk",
      km: "km",
      kn: "kn",
      ko: "ko",
      ku: "ku",
      ky: "ky",
      lo: "lo",
      lt: "lt",
      lv: "lv",
      mk: "mk",
      ml: "ml",
      mn: "mn-Cyrl",
      mr: "mr",
      ms: "ms",
      nb_NO: "nb",
      ne: "ne",
      nl: "nl",
      pa: "pa",
      pl_PL: "pl",
      pt: "pt",
      pt_BR: "pt",
      ro: "ro",
      ru: "ru",
      sk: "sk",
      sl: "sl",
      sq: "sq",
      sr: "sr-Cyrl",
      sv: "sv",
      sw: "sw",
      ta: "ta",
      te: "te",
      th: "th",
      tr_TR: "tr",
      tt: "tt",
      uk: "uk",
      ur: "ur",
      uz: "uz",
      vi: "vi",
      zh_CN: "zh-Hans",
      zh_TW: "zh-Hant",
    }

    def self.access_token_key
      "microsoft-translator"
    end

    def self.detect(post)
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||= begin
        text = post.raw.truncate(LENGTH_LIMIT, omission: nil)

        body = [{ "Text" => text }].to_json

        uri = URI(detect_endpoint)
        uri.query = URI.encode_www_form(self.default_query)

        response_body = result(uri.to_s, body, default_headers)

        response_body.first["language"]
      end
    end

    def self.translate(post)
      detected_lang = detect(post)

      if !SUPPORTED_LANG_MAPPING.keys.include?(detected_lang.to_sym) &&
           !SUPPORTED_LANG_MAPPING.values.include?(detected_lang.to_s)
        raise TranslatorError.new(I18n.t("translator.failed"))
      end

      raise TranslatorError.new(I18n.t("translator.too_long")) if post.cooked.length > LENGTH_LIMIT

      translated_text =
        from_custom_fields(post) do
          query = default_query.merge("from" => detected_lang, "to" => locale, "textType" => "html")

          body = [{ "Text" => post.cooked }].to_json

          uri = URI(translate_endpoint)
          uri.query = URI.encode_www_form(query)

          response_body = result(uri.to_s, body, default_headers)
          response_body.first["translations"].first["text"]
        end

      [detected_lang, translated_text]
    end

    private

    def self.detect_endpoint
      custom_endpoint? ? custom_detect_endpoint : DETECT_URI
    end

    def self.translate_endpoint
      custom_endpoint? ? custom_translate_endpoint : TRANSLATE_URI
    end

    def self.custom_base_endpoint
      "https://#{SiteSetting.translator_azure_custom_domain}.#{CUSTOM_URI_SUFFIX}"
    end

    def self.custom_detect_endpoint
      "#{custom_base_endpoint}/detect"
    end

    def self.custom_translate_endpoint
      "#{custom_base_endpoint}/translate"
    end

    def self.custom_endpoint?
      SiteSetting.translator_azure_custom_domain.present?
    end

    def self.locale
      SUPPORTED_LANG_MAPPING[I18n.locale] || (raise I18n.t("translator.not_supported"))
    end

    def self.post(uri, body, headers = {})
      connection = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
      connection.post(uri, body, headers)
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
      if SiteSetting.translator_azure_subscription_key.blank?
        raise TranslatorError.new(I18n.t("translator.microsoft.missing_key"))
      end

      headers = {
        "Content-Type" => "application/json",
        "Ocp-Apim-Subscription-Key" => SiteSetting.translator_azure_subscription_key,
      }

      if SiteSetting.translator_azure_region != "global"
        headers["Ocp-Apim-Subscription-Region"] = SiteSetting.translator_azure_region
      end

      headers
    end

    def self.default_query
      { "api-version" => "3.0" }
    end
  end
end
