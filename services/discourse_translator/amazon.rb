# frozen_string_literal: true

require_relative 'base'

module DiscourseTranslator
  class Amazon < Base
    require 'aws-sdk-translate'

    MAXLENGTH = 5000

    # Hash which maps Discourse's locale code to Amazon Translate's language code found in
    # https://docs.aws.amazon.com/translate/latest/dg/what-is-languages.html
    SUPPORTED_LANG_MAPPING = {
      af: 'af',
      sq: 'sq',
      am: 'am',
      ar: 'ar',
      hy: 'hy',
      az: 'az',
      bn: 'bn',
      bs: 'bs',
      bg: 'bg',
      ca: 'ca',
      zh: 'zh',
      zh_TW: 'zh-TW',
      hr: 'hr',
      cs: 'cs',
      da: 'da',
      fa_AF: 'fa-AF',
      nl: 'nl',
      en: 'en',
      et: 'et',
      fa: 'fa',
      tl: 'tl',
      fi: 'fi',
      fr: 'fr',
      fr_CA: 'fr-CA',
      ka: 'ka',
      de: 'de',
      el: 'el',
      gu: 'gu',
      ht: 'ht',
      ha: 'ha',
      he: 'he',
      hi: 'hi',
      hu: 'hu',
      is: 'is',
      id: 'id',
      ga: 'ga',
      it: 'it',
      ja: 'ja',
      kn: 'kn',
      kk: 'kk',
      ko: 'ko',
      lv: 'lv',
      lt: 'lt',
      mk: 'mk',
      ms: 'ms',
      ml: 'ml',
      mt: 'mt',
      mr: 'mr',
      mn: 'mn',
      no: 'no',
      ps: 'ps',
      pl: 'pl',
      pt: 'pt',
      pt_PT: 'pt-PT',
      pa: 'pa',
      ro: 'ro',
      ru: 'ru',
      sr: 'sr',
      si: 'si',
      sk: 'sk',
      sl: 'sl',
      so: 'so',
      es: 'es',
      es_MX: 'es-MX',
      sw: 'sw',
      sv: 'sv',
      ta: 'ta',
      te: 'te',
      th: 'th',
      tr: 'tr',
      uk: 'uk',
      ur: 'ur',
      uz: 'uz',
      vi: 'vi',
      cy: 'cy'
    }

    def self.access_token_key
      "aws-translator"
    end

    def self.detect(object)
      detected_lang = client.translate_text({
        text: get_text(object, MAXLENGTH),
        source_language_code: 'auto',
        target_language_code: SUPPORTED_LANG_MAPPING[I18n.locale]
      })&.source_language_code

      assign_lang_custom_field(object, detected_lang)
    end

    def self.translate(object, target_language = I18n.locale)
      result = client.translate_text({
        text: get_text(object, MAXLENGTH),
        source_language_code: "auto",
        target_language_code: SUPPORTED_LANG_MAPPING[target_language.to_sym],
      })
      detected_lang = assign_lang_custom_field(object, result.source_language_code)
      translated_text = from_custom_fields(object, target_language) { result.translated_text }
      [detected_lang, translated_text]
    rescue Aws::Translate::Errors::UnsupportedLanguagePairException
      raise I18n.t('translator.failed')
    end

    def self.client
      opts = { region: SiteSetting.translator_aws_region }

      if SiteSetting.translator_aws_key_id.present? && SiteSetting.translator_aws_secret_access.present?
        opts[:access_key_id] = SiteSetting.translator_aws_key_id
        opts[:secret_access_key] = SiteSetting.translator_aws_secret_access

      elsif SiteSetting.translator_aws_iam_role.present?
        sts_client = Aws::STS::Client.new(region: SiteSetting.translator_aws_region)

        opts[:credentials] = Aws::AssumeRoleCredentials.new(
          client: sts_client,
          role_arn: SiteSetting.translator_aws_iam_role,
          role_session_name: "discourse-aws-translator"
        )
      end

      @client ||= Aws::Translate::Client.new(opts)
    end

    def self.assign_lang_custom_field(object, value)
      field = get_custom_field(object)
      return object.custom_fields.delete(field) if value.nil?
      object.custom_fields[field] ||= value
    end
  end
end
