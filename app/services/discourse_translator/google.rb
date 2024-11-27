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

    def self.detect(topic_or_post)
      topic_or_post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||= result(
        DETECT_URI,
        q: text_for_detection(topic_or_post),
      )[
        "detections"
      ][
        0
      ].max { |a, b| a.confidence <=> b.confidence }[
        "language"
      ]
    end

    def self.translate_supported?(source, target)
      res = result(SUPPORT_URI, target: SUPPORTED_LANG_MAPPING[target])
      res["languages"].any? { |obj| obj["language"] == source }
    end

    def self.translate(topic_or_post)
      detected_lang = detect(topic_or_post)

      # the translate button appears if a given post is in a foreign language.
      # however the title of the topic may be in a different language, and may be in the user's language.
      # if this is the case, when this is called for a topic, the detected_lang will be the user's language,
      # so the user's language and the detected language will be the same. For example, both could be "en"
      # google will choke on this and return an error instead of gracefully handling it by returning the original
      # string.
      # ---
      # here we handle that situation by returning the original string if the source and target lang are the same.
      return detected_lang, get_text(topic_or_post) if (detected_lang&.to_s.eql? I18n.locale.to_s)

      raise I18n.t("translator.failed") unless translate_supported?(detected_lang, I18n.locale)

      translated_text =
        from_custom_fields(topic_or_post) do
          res =
            result(
              TRANSLATE_URI,
              q: text_for_translation(topic_or_post),
              source: detected_lang,
              target: SUPPORTED_LANG_MAPPING[I18n.locale],
            )
          res["translations"][0]["translatedText"]
        end

      [detected_lang, translated_text]
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