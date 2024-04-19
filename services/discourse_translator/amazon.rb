# frozen_string_literal: true

require_relative "base"

module DiscourseTranslator
  class Amazon < Base
    require "aws-sdk-translate"

    MAX_BYTES = 10_000

    # Hash which maps Discourse's locale code to Amazon Translate's language code found in
    # https://docs.aws.amazon.com/translate/latest/dg/what-is-languages.html
    SUPPORTED_LANG_MAPPING = {
      af: "af",
      sq: "sq",
      am: "am",
      ar: "ar",
      hy: "hy",
      az: "az",
      bn: "bn",
      bs: "bs",
      bg: "bg",
      ca: "ca",
      zh: "zh",
      zh_TW: "zh-TW",
      hr: "hr",
      cs: "cs",
      da: "da",
      fa_AF: "fa-AF",
      nl: "nl",
      en: "en",
      et: "et",
      fa: "fa",
      tl: "tl",
      fi: "fi",
      fr: "fr",
      fr_CA: "fr-CA",
      ka: "ka",
      de: "de",
      el: "el",
      gu: "gu",
      ht: "ht",
      ha: "ha",
      he: "he",
      hi: "hi",
      hu: "hu",
      is: "is",
      id: "id",
      ga: "ga",
      it: "it",
      ja: "ja",
      kn: "kn",
      kk: "kk",
      ko: "ko",
      lv: "lv",
      lt: "lt",
      mk: "mk",
      ms: "ms",
      ml: "ml",
      mt: "mt",
      mr: "mr",
      mn: "mn",
      no: "no",
      ps: "ps",
      pl: "pl",
      pt: "pt",
      pt_PT: "pt-PT",
      pa: "pa",
      ro: "ro",
      ru: "ru",
      sr: "sr",
      si: "si",
      sk: "sk",
      sl: "sl",
      so: "so",
      es: "es",
      es_MX: "es-MX",
      sw: "sw",
      sv: "sv",
      ta: "ta",
      te: "te",
      th: "th",
      tr: "tr",
      uk: "uk",
      ur: "ur",
      uz: "uz",
      vi: "vi",
      cy: "cy",
    }

    # The API expects a maximum of 10k __bytes__ of text
    def self.truncate(text)
      return text if text.bytesize <= MAX_BYTES
      text = text.byteslice(...MAX_BYTES)
      text = text.byteslice(...text.bytesize - 1) until text.valid_encoding?
      text
    end

    def self.access_token_key
      "aws-translator"
    end

    def self.detect(topic_or_post)
      text = truncate get_text(topic_or_post)

      return if text.blank?

      detected_lang =
        client.translate_text(
          {
            text: text,
            source_language_code: "auto",
            target_language_code: SUPPORTED_LANG_MAPPING[I18n.locale],
          },
        )&.source_language_code

      assign_lang_custom_field(topic_or_post, detected_lang)
    end

    def self.translate(topic_or_post)
      from_custom_fields(topic_or_post) do
        result =
          client.translate_text(
            {
              text: truncate(get_text(topic_or_post)),
              source_language_code: "auto",
              target_language_code: SUPPORTED_LANG_MAPPING[I18n.locale],
            },
          )

        detected_lang = assign_lang_custom_field(topic_or_post, result.source_language_code)

        [detected_lang, result.translated_text]
      end
    rescue Aws::Translate::Errors::UnsupportedLanguagePairException
      raise I18n.t("translator.failed")
    end

    def self.client
      opts = { region: SiteSetting.translator_aws_region }

      if SiteSetting.translator_aws_key_id.present? &&
           SiteSetting.translator_aws_secret_access.present?
        opts[:access_key_id] = SiteSetting.translator_aws_key_id
        opts[:secret_access_key] = SiteSetting.translator_aws_secret_access
      elsif SiteSetting.translator_aws_iam_role.present?
        sts_client = Aws::STS::Client.new(region: SiteSetting.translator_aws_region)

        opts[:credentials] = Aws::AssumeRoleCredentials.new(
          client: sts_client,
          role_arn: SiteSetting.translator_aws_iam_role,
          role_session_name: "discourse-aws-translator",
        )
      end

      @client ||= Aws::Translate::Client.new(opts)
    end

    def self.assign_lang_custom_field(post, value)
      if value.nil?
        return post.custom_fields.delete(DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD)
      end
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||= value
    end
  end
end
