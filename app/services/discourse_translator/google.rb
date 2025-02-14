# frozen_string_literal: true

require_relative "base"
require "json"

module DiscourseTranslator
  class Google < Base
    TRANSLATE_URI = "https://www.googleapis.com/language/translate/v2".freeze
    DETECT_URI = "https://www.googleapis.com/language/translate/v2/detect".freeze
    SUPPORT_URI = "https://www.googleapis.com/language/translate/v2/languages".freeze

    # Hash which maps Discourse's locale code to Google Translate's locale code found in
    # https://cloud.google.com/translate/docs/languages
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
      hi: "hi",
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
      zh_CN: "zh-CN",
      zh_TW: "zh-TW",
      tr_TR: "tr",
      pt_BR: "pt",
      pl_PL: "pl",
      no_NO: "no",
      nb_NO: "no",
      fa_IR: "fa",
    }

    def self.access_token_key
      "google-translator"
    end

    def self.access_token
      return SiteSetting.translator_google_api_key if SiteSetting.translator_google_api_key.present?
      raise ProblemCheckedTranslationError.new("NotFound: Google Api Key not set.")
    end

    def self.detect!(topic_or_post)
      save_detected_locale(topic_or_post) do
        result(DETECT_URI, q: text_for_detection(topic_or_post))["detections"][0].max do |a, b|
          a.confidence <=> b.confidence
        end[
          "language"
        ]
      end
    end

    def self.translate_supported?(source, target)
      res = result(SUPPORT_URI, target: SUPPORTED_LANG_MAPPING[target])
      res["languages"].any? { |obj| obj["language"] == source }
    end

    def self.translate!(translatable, target_locale_sym = I18n.locale)
      detected_locale = detect(translatable)
      save_translation(translatable, target_locale_sym) do
        res =
          result(
            TRANSLATE_URI,
            q: text_for_translation(translatable),
            source: detected_locale,
            target: SUPPORTED_LANG_MAPPING[target_locale_sym],
          )
        res["translations"][0]["translatedText"]
      end
    end

    def self.result(url, body)
      body[:key] = access_token

      response =
        Excon.post(
          url,
          body: URI.encode_www_form(body),
          headers: {
            "Content-Type" => "application/x-www-form-urlencoded",
            "Referer" => Discourse.base_url,
          },
        )

      body = nil
      begin
        body = JSON.parse(response.body)
      rescue JSON::ParserError
      end

      if response.status != 200
        if body && body["error"]
          ProblemCheckTracker[:translator_error].problem!(
            details: {
              provider: "Google",
              code: body["error"]["code"],
              message: body["error"]["message"],
            },
          )
          raise ProblemCheckedTranslationError.new(body["error"]["message"])
        else
          raise TranslatorError.new(response.inspect)
        end
      else
        ProblemCheckTracker[:translator_error].no_problem!
        body["data"]
      end
    end
  end
end
