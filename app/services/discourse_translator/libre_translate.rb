# frozen_string_literal: true

require_relative "base"
require "json"

module DiscourseTranslator
  class LibreTranslate < Base
    SUPPORTED_LANG_MAPPING = {
      en: "en",
      en_GB: "en",
      en_US: "en",
      ar: "ar",
      bg: "bg",
      bs_BA: "bs",
      ca: "ca",
      cs: "cs",
      da: "da",
      de: "de",
      el: "el",
      es: "es",
      et: "et",
      fi: "fi",
      fr: "fr",
      he: "iw",
      hr: "hr",
      hu: "hu",
      hy: "hy",
      id: "id",
      it: "it",
      ja: "ja",
      ka: "ka",
      kk: "kk",
      ko: "ko",
      ky: "ky",
      lv: "lv",
      mk: "mk",
      nl: "nl",
      pt: "pt",
      ro: "ro",
      ru: "ru",
      sk: "sk",
      sl: "sl",
      sq: "sq",
      sr: "sr",
      sv: "sv",
      tg: "tg",
      te: "te",
      th: "th",
      uk: "uk",
      uz: "uz",
      zh_CN: "zh",
      zh_TW: "zh",
      tr_TR: "tr",
      pt_BR: "pt",
      pl_PL: "pl",
      no_NO: "no",
      nb_NO: "no",
      fa_IR: "fa",
    }

    def self.translate_uri
      SiteSetting.translator_libretranslate_endpoint + "/translate"
    end

    def self.detect_uri
      SiteSetting.translator_libretranslate_endpoint + "/detect"
    end

    def self.support_uri
      SiteSetting.translator_libretranslate_endpoint + "/languages"
    end

    def self.access_token_key
      "libretranslate-translator"
    end

    def self.access_token
      SiteSetting.translator_libretranslate_api_key
    end

    def self.detect!(topic_or_post)
      save_detected_locale(topic_or_post) do
        res =
          result(
            detect_uri,
            q: ActionController::Base.helpers.strip_tags(text_for_detection(topic_or_post)),
          )
        !res.empty? ? res[0]["language"] : "en"
      end
    end

    def self.translate_supported?(source, target)
      lang = SUPPORTED_LANG_MAPPING[target]
      res = get(support_uri)
      res.any? { |obj| obj["code"] == source } && res.any? { |obj| obj["code"] == lang }
    end

    def self.translate!(translatable, target_locale_sym = I18n.locale)
      detected_lang = detect(translatable)

      save_translation(translatable, target_locale_sym) do
        res =
          result(
            translate_uri,
            q: text_for_translation(translatable),
            source: detected_lang,
            target: SUPPORTED_LANG_MAPPING[target_locale],
            format: "html",
          )
        res["translatedText"]
      end
    end

    def self.get(url)
      begin
        response = Excon.get(url)
        body = JSON.parse(response.body)
        status = response.status
      rescue JSON::ParserError, Excon::Error::Socket, Excon::Error::Timeout
        body = I18n.t("translator.not_available")
        status = 500
      end

      if status != 200
        raise TranslatorError.new(body || response.inspect)
      else
        body
      end
    end

    def self.result(url, body)
      begin
        body[:api_key] = access_token

        response =
          Excon.post(
            url,
            body: URI.encode_www_form(body),
            headers: {
              "Content-Type" => "application/x-www-form-urlencoded",
            },
          )

        body = JSON.parse(response.body)
        status = response.status
      rescue JSON::ParserError, Excon::Error::Socket, Excon::Error::Timeout
        body = I18n.t("translator.not_available")
        status = 500
      end

      if status != 200
        raise TranslatorError.new(body || response.inspect)
      else
        body
      end
    end
  end
end
