# frozen_string_literal: true

require_relative 'base'

module DiscourseTranslator
  class Yandex < Base
    TRANSLATE_URI = "https://translate.yandex.net/api/v1.5/tr.json/translate"
    DETECT_URI = "https://translate.yandex.net/api/v1.5/tr.json/detect"

    SUPPORTED_LANG = {
      pt_BR: 'pt',
      pl_PL: 'pl',
      no_NO: 'no',
      fa_IR: 'fa',
      zh_CN: 'zh',
      zh_TW: 'zh',
      tr_TR: 'tr',
      en: 'en',
      en_US: 'en',
      en_GB: 'en',
      az: 'az',
      ml: 'ml',
      sq: 'sq',
      mt: 'mt',
      am: 'am',
      mk: 'mk',
      mi: 'mi',
      ar: 'ar',
      mr: 'mr',
      hy: 'hy',
      mhr: 'mhr',
      af: 'af',
      mn: 'mn',
      eu: 'eu',
      de: 'de',
      ba: 'ba',
      ne: 'ne',
      be: 'be',
      no: 'no',
      bn: 'bn',
      pa: 'pa',
      my: 'my',
      pap: 'pap',
      bg: 'bg',
      fa: 'fa',
      bs: 'bs',
      pl: 'pl',
      cy: 'cy',
      pt: 'pt',
      hu: 'hu',
      ro: 'ro',
      vi: 'vi',
      ru: 'ru',
      ht: 'ht',
      ceb: 'ceb',
      gl: 'gl',
      sr: 'sr',
      nl: 'nl',
      si: 'si',
      mrj: 'mrj',
      sk: 'sk',
      el: 'el',
      sl: 'sl',
      ka: 'ka',
      sw: 'sw',
      gu: 'gu',
      su: 'su',
      da: 'da',
      tg: 'tg',
      he: 'he',
      th: 'th',
      yi: 'yi',
      tl: 'tl',
      id: 'id',
      ta: 'ta',
      ga: 'ga',
      tt: 'tt',
      it: 'it',
      te: 'te',
      is: 'is',
      tr: 'tr',
      es: 'es',
      udm: 'udm',
      kk: 'kk',
      uz: 'uz',
      kn: 'kn',
      uk: 'uk',
      ca: 'ca',
      ur: 'ur',
      ky: 'ky',
      fi: 'fi',
      zh: 'zh',
      fr: 'fr',
      ko: 'ko',
      hi: 'hi',
      xh: 'xh',
      hr: 'hr',
      km: 'km',
      cs: 'cs',
      lo: 'lo',
      sv: 'sv',
      la: 'la',
      gd: 'gd',
      lv: 'lv',
      et: 'et',
      lt: 'lt',
      eo: 'eo',
      lb: 'lb',
      jv: 'jv',
      mg: 'mg',
      ja: 'ja',
      ms: 'ms',
    }

    def self.access_token_key
      "yandex-translator"
    end

    def self.access_token
      SiteSetting.translator_yandex_api_key || (raise TranslatorError.new("NotFound: Yandex API Key not set."))
    end

    def self.detect(post)
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||= begin
        query = default_query.merge(
          "text" => post.raw
        )

        uri = URI(DETECT_URI)
        uri.query = URI.encode_www_form(query)

        response_body = result(uri.to_s, "", default_headers)

        response_body["lang"]
      end
    end

    def self.translate(post)
      detected_lang = detect(post)

      if !SUPPORTED_LANG.keys.include?(detected_lang.to_sym) &&
        !SUPPORTED_LANG.values.include?(detected_lang.to_s)

        raise TranslatorError.new(I18n.t('translator.failed'))
      end

      translated_text = from_custom_fields(post) do
        query = default_query.merge(
          "lang" => "#{detected_lang}-#{locale}",
          "text" => post.cooked,
          "format" => "html"
        )

        uri = URI(TRANSLATE_URI)
        uri.query = URI.encode_www_form(query)

        response_body = result(uri.to_s, "", default_headers)
        response_body["text"][0]
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
        'Content-Type' => 'application/x-www-form-urlencoded'
      }
    end

    def self.default_query
      {
        key: access_token
      }
    end
  end
end
