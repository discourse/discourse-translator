# frozen_string_literal: true

module DiscourseTranslator
  module Provider
    class Yandex < BaseProvider
      TRANSLATE_URI = "https://translate.yandex.net/api/v1.5/tr.json/translate"
      DETECT_URI = "https://translate.yandex.net/api/v1.5/tr.json/detect"

      # Hash which maps Discourse's locale code to Yandex Translate's language code found in
      # https://yandex.com/dev/translate/doc/dg/concepts/api-overview.html
      SUPPORTED_LANG_MAPPING = {
        pt_BR: "pt",
        pl_PL: "pl",
        no_NO: "no",
        fa_IR: "fa",
        zh_CN: "zh",
        zh_TW: "zh",
        tr_TR: "tr",
        en: "en",
        en_US: "en",
        en_GB: "en",
        az: "az",
        ml: "ml",
        sq: "sq",
        mt: "mt",
        am: "am",
        mk: "mk",
        mi: "mi",
        ar: "ar",
        mr: "mr",
        hy: "hy",
        mhr: "mhr",
        af: "af",
        mn: "mn",
        eu: "eu",
        de: "de",
        ba: "ba",
        ne: "ne",
        be: "be",
        no: "no",
        bn: "bn",
        pa: "pa",
        my: "my",
        pap: "pap",
        bg: "bg",
        fa: "fa",
        bs: "bs",
        pl: "pl",
        cy: "cy",
        pt: "pt",
        hu: "hu",
        ro: "ro",
        vi: "vi",
        ru: "ru",
        ht: "ht",
        ceb: "ceb",
        gl: "gl",
        sr: "sr",
        nl: "nl",
        si: "si",
        mrj: "mrj",
        sk: "sk",
        el: "el",
        sl: "sl",
        ka: "ka",
        sw: "sw",
        gu: "gu",
        su: "su",
        da: "da",
        tg: "tg",
        he: "he",
        th: "th",
        yi: "yi",
        tl: "tl",
        id: "id",
        ta: "ta",
        ga: "ga",
        tt: "tt",
        it: "it",
        te: "te",
        is: "is",
        tr: "tr",
        es: "es",
        udm: "udm",
        kk: "kk",
        uz: "uz",
        kn: "kn",
        uk: "uk",
        ca: "ca",
        ur: "ur",
        ky: "ky",
        fi: "fi",
        zh: "zh",
        fr: "fr",
        ko: "ko",
        hi: "hi",
        xh: "xh",
        hr: "hr",
        km: "km",
        cs: "cs",
        lo: "lo",
        sv: "sv",
        la: "la",
        gd: "gd",
        lv: "lv",
        et: "et",
        lt: "lt",
        eo: "eo",
        lb: "lb",
        jv: "jv",
        mg: "mg",
        ja: "ja",
        ms: "ms",
      }

      def self.access_token_key
        "yandex-translator"
      end

      def self.access_token
        SiteSetting.translator_yandex_api_key ||
          (raise TranslatorError.new("NotFound: Yandex API Key not set."))
      end

      def self.detect!(topic_or_post)
        query = default_query.merge("text" => text_for_detection(topic_or_post))
        uri = URI(DETECT_URI)
        uri.query = URI.encode_www_form(query)
        result(uri.to_s, "", default_headers)["lang"]
      end

      def self.translate_post!(post, target_locale_sym = I18n.locale, opts = {})
        raw = opts.key?(:raw) ? opts[:raw] : !opts[:cooked]
        text = text_for_translation(post, raw:)

        detected_lang = detect(post)
        locale = SUPPORTED_LANG_MAPPING[target_locale_sym]

        send_for_translation(text, detected_lang, locale)
      end

      def self.translate_topic!(topic, target_locale_sym = I18n.locale)
        detected_lang = detect(topic)
        locale = SUPPORTED_LANG_MAPPING[target_locale_sym]
        text = text_for_translation(topic)

        send_for_translation(text, detected_lang, locale)
      end

      def self.translate_text!(text, target_locale_sym = I18n.locale)
        # Not supported for v1.5 https://translate.yandex.com/developers
        raise TranslatorError.new(I18n.t("translator.not_supported"))
      end

      def self.translate_supported?(detected_lang, target_lang)
        SUPPORTED_LANG_MAPPING.keys.include?(detected_lang.to_sym) &&
          SUPPORTED_LANG_MAPPING.values.include?(detected_lang.to_s)
      end

      private

      def self.send_for_translation(text, source_locale, target_locale)
        query =
          default_query.merge(
            "lang" => "#{source_locale}-#{target_locale}",
            "text" => text,
            "format" => "html",
          )

        uri = URI(TRANSLATE_URI)
        uri.query = URI.encode_www_form(query)

        response_body = result(uri.to_s, "", default_headers)
        response_body["text"][0]
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
        { "Content-Type" => "application/x-www-form-urlencoded" }
      end

      def self.default_query
        { key: access_token }
      end
    end
  end
end
