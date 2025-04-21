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
      ga: "ga",
      gl: "gl",
      gom: "gom",
      gu: "gu",
      ha: "ha",
      he: "he",
      hi: "hi",
      hr: "hr",
      hsb: "hsb",
      ht: "ht",
      hu: "hu",
      hy: "hy",
      id: "id",
      ig: "ig",
      ikt: "ikt",
      is: "is",
      it: "it",
      iu: "iu",
      iu_Latn: "iu-Latn",
      ja: "ja",
      ka: "ka",
      kk: "kk",
      km: "km",
      kmr: "kmr",
      kn: "kn",
      ko: "ko",
      ks: "ks",
      ku: "ku",
      ky: "ky",
      ln: "ln",
      lo: "lo",
      lt: "lt",
      lug: "lug",
      lv: "lv",
      lzh: "lzh",
      mai: "mai",
      mg: "mg",
      mi: "mi",
      mk: "mk",
      ml: "ml",
      mn: "mn-Cyrl",
      mn_Cyrl: "mn-Cyrl",
      mn_Mong: "mn-Mong",
      mr: "mr",
      ms: "ms",
      mt: "mt",
      mww: "mww",
      my: "my",
      nb: "nb",
      nb_NO: "nb",
      ne: "ne",
      nl: "nl",
      nso: "nso",
      nya: "nya",
      or: "or",
      otq: "otq",
      pa: "pa",
      pl: "pl",
      pl_PL: "pl",
      prs: "prs",
      ps: "ps",
      pt: "pt",
      pt_BR: "pt",
      pt_pt: "pt",
      ro: "ro",
      ru: "ru",
      run: "run",
      rw: "rw",
      sd: "sd",
      si: "si",
      sk: "sk",
      sl: "sl",
      sm: "sm",
      sn: "sn",
      so: "so",
      sq: "sq",
      sr: "sr-Cyrl",
      sr_Cyrl: "sr-Cyrl",
      sr_Latn: "sr-Latn",
      st: "st",
      sv: "sv",
      sw: "sw",
      ta: "ta",
      te: "te",
      th: "th",
      ti: "ti",
      tk: "tk",
      tlh_Latn: "tlh-Latn",
      tlh_Piqd: "tlh-Piqd",
      tn: "tn",
      to: "to",
      tr: "tr",
      tr_TR: "tr",
      tt: "tt",
      ty: "ty",
      ug: "ug",
      uk: "uk",
      ur: "ur",
      uz: "uz",
      vi: "vi",
      xh: "xh",
      yo: "yo",
      yua: "yua",
      yue: "yue",
      zh_CN: "zh-Hans",
      zh_TW: "zh-Hant",
      zu: "zu",
    }

    def self.access_token_key
      "microsoft-translator"
    end

    def self.detect!(topic_or_post)
      body = [{ "Text" => text_for_detection(topic_or_post) }].to_json
      uri = URI(detect_endpoint)
      uri.query = URI.encode_www_form(self.default_query)
      result(uri.to_s, body, default_headers).first["language"]
    end

    def self.translate_translatable!(translatable, target_locale_sym = I18n.locale)
      detected_lang = detect(translatable)

      if text_for_translation(translatable).length > LENGTH_LIMIT
        raise TranslatorError.new(I18n.t("translator.too_long"))
      end
      locale =
        SUPPORTED_LANG_MAPPING[target_locale_sym] || (raise I18n.t("translator.not_supported"))

      query = default_query.merge("from" => detected_lang, "to" => locale, "textType" => "html")
      body = [{ "Text" => text_for_translation(translatable) }].to_json
      uri = URI(translate_endpoint)
      uri.query = URI.encode_www_form(query)
      response_body = result(uri.to_s, body, default_headers)
      response_body.first["translations"].first["text"]
    end

    def self.translate_supported?(detected_lang, target_lang)
      SUPPORTED_LANG_MAPPING.keys.include?(detected_lang.to_sym) &&
        SUPPORTED_LANG_MAPPING.values.include?(detected_lang.to_s)
    end

    private

    def self.detect_endpoint
      custom_endpoint? ? custom_detect_endpoint : DETECT_URI
    end

    def self.translate_endpoint
      custom_endpoint? ? custom_translate_endpoint : TRANSLATE_URI
    end

    def self.custom_base_endpoint
      "https://#{SiteSetting.translator_azure_custom_subdomain}.#{CUSTOM_URI_SUFFIX}"
    end

    def self.custom_detect_endpoint
      "#{custom_base_endpoint}/detect"
    end

    def self.custom_translate_endpoint
      "#{custom_base_endpoint}/translate"
    end

    def self.custom_endpoint?
      SiteSetting.translator_azure_custom_subdomain.present?
    end

    def self.post(uri, body, headers = {})
      connection = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
      connection.post(uri, body, headers)
    end

    def self.result(uri, body, headers)
      response = post(uri, body, headers)
      response_body = JSON.parse(response.body)

      if response.status != 200
        if response_body["error"] && response_body["error"]["code"]
          ProblemCheckTracker[:translator_error].problem!(
            details: {
              provider: "Microsoft",
              code: response_body["error"]["code"],
              message: response_body["error"]["message"],
            },
          )
          raise ProblemCheckedTranslationError.new(response_body)
        end
        raise TranslatorError.new(response_body)
      else
        ProblemCheckTracker[:translator_error].no_problem!
        response_body
      end
    end

    def self.default_headers
      if SiteSetting.translator_azure_subscription_key.blank?
        raise ProblemCheckedTranslationError.new(I18n.t("translator.microsoft.missing_key"))
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
