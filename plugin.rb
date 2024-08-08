# frozen_string_literal: true

# name: discourse-translator
# about: Translates posts on Discourse using Microsoft, Google, Yandex or LibreTranslate translation APIs.
# meta_topic_id: 32630
# version: 0.3.0
# authors: Alan Tan
# url: https://github.com/discourse/discourse-translator

gem "aws-sdk-translate", "1.35.0", require: false

enabled_site_setting :translator_enabled
register_asset "stylesheets/common/post.scss"

after_initialize do
  module ::DiscourseTranslator
    PLUGIN_NAME = "discourse_translator".freeze
    DETECTED_LANG_CUSTOM_FIELD = "post_detected_lang".freeze
    TRANSLATED_CUSTOM_FIELD = "translated_text".freeze

    autoload :Microsoft,
             "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/microsoft"
    autoload :Google,
             "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/google"
    autoload :Amazon,
             "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/amazon"
    autoload :Yandex,
             "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/yandex"
    autoload :LibreTranslate,
             "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/libretranslate"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseTranslator
    end
  end

  require_relative "app/services/problem_check/microsoft_azure_key"
  register_problem_check ProblemCheck::MicrosoftAzureKey

  class DiscourseTranslator::TranslatorController < ::ApplicationController
    before_action :ensure_logged_in

    def translate
      raise PluginDisabled if !SiteSetting.translator_enabled

      if !current_user.staff?
        RateLimiter.new(
          current_user,
          "translate_post",
          SiteSetting.max_translations_per_minute,
          1.minute,
        ).performed!
      end

      params.require(:post_id)
      post = Post.find_by(id: params[:post_id])
      raise Discourse::InvalidParameters.new(:post_id) if post.blank?
      guardian.ensure_can_see!(post)

      if !guardian.user_group_allow_translate?
        raise Discourse::InvalidAccess.new(
                "not_in_group",
                SiteSetting.restrict_translation_by_group,
                custom_message: "not_in_group.user_not_in_group",
                group: current_user.groups.pluck(:id),
              )
      end

      if !guardian.poster_group_allow_translate?(post)
        raise Discourse::InvalidAccess.new(
                "not_in_group",
                SiteSetting.restrict_translation_by_poster_group,
                custom_message: "not_in_group.poster_not_in_group",
              )
      end

      begin
        title_json = {}
        detected_lang, translation =
          "DiscourseTranslator::#{SiteSetting.translator}".constantize.translate(post)
        if post.is_first_post?
          _, title_translation =
            "DiscourseTranslator::#{SiteSetting.translator}".constantize.translate(post.topic)
          title_json = { title_translation: title_translation }
        end
        render json: { translation: translation, detected_lang: detected_lang }.merge(title_json),
               status: 200
      rescue ::DiscourseTranslator::TranslatorError => e
        render_json_error e.message, status: 422
      end
    end
  end

  Post.register_custom_field_type(::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD, :json)
  Topic.register_custom_field_type(::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD, :json)

  module ::Jobs
    class TranslatorMigrateToAzurePortal < ::Jobs::Onceoff
      def execute_onceoff(args)
        %w[translator_client_id translator_client_secret].each { |name| DB.exec <<~SQL }
          DELETE FROM site_settings WHERE name = '#{name}'
          SQL

        DB.exec <<~SQL
          UPDATE site_settings
          SET name = 'translator_azure_subscription_key'
          WHERE name = 'azure_subscription_key'
        SQL
      end
    end

    class DetectTranslation < ::Jobs::Base
      sidekiq_options retry: false

      def execute(args)
        return if !SiteSetting.translator_enabled

        post = Post.find_by(id: args[:post_id])
        return unless post

        DistributedMutex.synchronize("detect_translation_#{post.id}") do
          begin
            "DiscourseTranslator::#{SiteSetting.translator}".constantize.detect(post)
            if !post.custom_fields_clean?
              post.save_custom_fields
              post.publish_change_to_clients! :revised
            end
          rescue ::DiscourseTranslator::MicrosoftNoAzureKeyError
            # We already have ProblemCheck::MicrosoftAzureKey, no need to log errors here
          end
        end
      end
    end
  end

  on(:post_process) { |post| Jobs.enqueue(:detect_translation, post_id: post.id) }

  topic_view_post_custom_fields_allowlister { [::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] }

  require_relative "lib/discourse_translator/guardian_extension"
  require_relative "lib/discourse_translator/post_extension"
  require_relative "lib/discourse_translator/topic_extension"

  reloadable_patch do |plugin|
    Guardian.prepend(DiscourseTranslator::GuardianExtension)
    Post.prepend(DiscourseTranslator::PostExtension)
    Topic.prepend(DiscourseTranslator::TopicExtension)
  end

  add_to_serializer :post, :can_translate do
    return false if !SiteSetting.translator_enabled
    if !scope.user_group_allow_translate? || !scope.poster_group_allow_translate?(object)
      return false
    end
    return false if raw.blank? || post_type == Post.types[:small_action]

    detected_lang = post_custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]

    if !detected_lang
      Jobs.enqueue(:detect_translation, post_id: object.id)
      false
    else
      detected_lang !=
        "DiscourseTranslator::#{SiteSetting.translator}::SUPPORTED_LANG_MAPPING".constantize[
          I18n.locale
        ]
    end
  end

  DiscourseTranslator::Engine.routes.draw { post "translate" => "translator#translate" }

  Discourse::Application.routes.append { mount ::DiscourseTranslator::Engine, at: "translator" }
end
