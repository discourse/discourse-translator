# frozen_string_literal: true

# name: discourse-translator
# about: Provides inline translation of posts.
# version: 0.3.0
# authors: Alan Tan
# url: https://github.com/discourse/discourse-translator

gem 'aws-sdk-translate', '1.35.0', require: false

load File.expand_path('../lib/validators/default_title_languages_validator.rb', __FILE__)

enabled_site_setting :translator_enabled
register_asset "stylesheets/common/common.scss"

after_initialize do
  module ::DiscourseTranslator
    PLUGIN_NAME = "discourse_translator".freeze
    DETECTED_LANG_CUSTOM_FIELD = 'post_detected_lang'.freeze
    DETECTED_TITLE_LANG_CUSTOM_FIELD = 'topic_title_detected_lang'.freeze
    TRANSLATED_CUSTOM_FIELD = 'translated_text'.freeze

    autoload :Microsoft, "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/microsoft"
    autoload :Google, "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/google"
    autoload :Amazon, "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/amazon"
    autoload :Yandex, "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/yandex"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseTranslator
    end

    def self.current_service
      "DiscourseTranslator::#{SiteSetting.translator}".constantize
    end
  end

  class DiscourseTranslator::TranslatorController < ::ApplicationController
    before_action :ensure_logged_in
    before_action :ensure_plugin_enabled
    before_action :rate_limit
    before_action :find_object

    def translate
      begin
        detected_lang, translation = DiscourseTranslator.current_service.translate(@object)
        render json: { translation: translation, detected_lang: detected_lang }, status: 200
      rescue ::DiscourseTranslator::TranslatorError => e
        render_json_error e.message, status: 422
      end
    end

    protected

    def ensure_plugin_enabled
      raise PluginDisabled if !SiteSetting.translator_enabled
    end

    def rate_limit
      if !current_user.staff?
        RateLimiter.new(current_user, "translate", SiteSetting.max_translations_per_minute, 1.minute).performed!
      end
    end

    def find_object
      raise Discourse::InvalidParameters.new unless params[:post_id] || params[:topic_id]
      @object = params[:post_id] ? Post.find_by(id: params[:post_id]) : Topic.find_by(id: params[:topic_id])
      raise Discourse::InvalidParameters.new if @object.blank?
      guardian.ensure_can_see!(@object)
    end
  end

  Post.register_custom_field_type(::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD, :json)
  Topic.register_custom_field_type(::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD, :json)

  add_model_callback(:post, :before_update) do
    if raw_changed?
      custom_fields.delete(DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD)
      custom_fields.delete(DiscourseTranslator::TRANSLATED_CUSTOM_FIELD)
    end
  end

  add_model_callback(:topic, :before_update) do
    if title_changed?
      custom_fields.delete(DiscourseTranslator::DETECTED_TITLE_LANG_CUSTOM_FIELD)
      custom_fields.delete(DiscourseTranslator::TRANSLATED_CUSTOM_FIELD)
    end
  end

  add_to_class(:topic, :title_translations) do
    if !custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD].nil?
      custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD]
    else
      {}
    end
  end

  add_to_class(:topic, :title_language) { custom_fields[DiscourseTranslator::DETECTED_TITLE_LANG_CUSTOM_FIELD] }

  add_to_class(:topic, :translated_title) do
    language = DiscourseTranslator.current_service::SUPPORTED_LANG_MAPPING[I18n.locale]
    translation = title_translations[language]
    translation.present? ? translation : title
  end

  on(:post_created) do |post, options, user|
    if SiteSetting.translator_default_title_languages.present? && post.is_first_post?
      Jobs.enqueue(:translate_topic_title, topic_id: post.topic.id)
    end
  end

  module ::Jobs
    class TranslatorMigrateToAzurePortal < ::Jobs::Onceoff
      def execute_onceoff(args)
        ["translator_client_id", "translator_client_secret"].each do |name|

          DB.exec <<~SQL
          DELETE FROM site_settings WHERE name = '#{name}'
          SQL
        end

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
          DiscourseTranslator.current_service.detect(post)
          post.save_custom_fields unless post.custom_fields_clean?
          post.publish_change_to_clients! :revised
        end
      end
    end

    class TranslateTopicTitle < ::Jobs::Base
      sidekiq_options retry: false

      def execute(args)
        return if !SiteSetting.translator_enabled

        languages = SiteSetting.translator_default_title_languages.split('|')
        topic = Topic.find_by(id: args[:topic_id])
        return unless topic && languages.present?

        languages.each do |language|
          DiscourseTranslator.current_service.translate(topic, language)
        end
      end
    end
  end

  def post_process(post)
    return if !SiteSetting.translator_enabled
    Jobs.enqueue(:detect_translation, post_id: post.id)
  end
  listen_for :post_process

  topic_view_post_custom_fields_allowlister { [::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] }
  add_preloaded_topic_list_custom_field(::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD)
  add_preloaded_topic_list_custom_field(::DiscourseTranslator::DETECTED_TITLE_LANG_CUSTOM_FIELD)

  class ::PostSerializer
    attributes :can_translate

    def can_translate
      return false if !SiteSetting.translator_enabled

      detected_lang = post_custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]

      if !detected_lang
        Jobs.enqueue(:detect_translation, post_id: object.id)
        false
      else
        detected_lang != DiscourseTranslator.current_service::SUPPORTED_LANG_MAPPING[I18n.locale]
      end
    end

  end

  add_to_serializer(:topic_list_item, :title) do
    SiteSetting.translator_show_topic_titles_in_user_locale ? object.translated_title : object.title
  end
  add_to_serializer(:topic_list_item, :fancy_title) do
    SiteSetting.translator_show_topic_titles_in_user_locale ? object.translated_title : object.fancy_title
  end
  add_to_serializer(:topic_list_item, :title_translated) { title != object.title }
  add_to_serializer(:topic_list_item, :original_title) { object.title }
  add_to_serializer(:topic_list_item, :include_original_title?) { title_translated }
  add_to_serializer(:topic_list_item, :title_language) { object.title_language }

  add_to_serializer(:topic_view, :title) do
    SiteSetting.translator_show_topic_titles_in_user_locale ? object.topic.translated_title : object.topic.title
  end
  add_to_serializer(:topic_view, :fancy_title) do
    SiteSetting.translator_show_topic_titles_in_user_locale ? object.topic.translated_title : object.topic.fancy_title
  end
  add_to_serializer(:topic_view, :title_translated) { title != object.topic.title }
  add_to_serializer(:topic_view, :original_title) { object.topic.title }
  add_to_serializer(:topic_view, :include_original_title?) { title_translated }
  add_to_serializer(:topic_view, :title_language) { object.topic.title_language }
  add_to_serializer(:topic_view, :can_translate_title) { title_language.to_sym != I18n.locale }

  DiscourseTranslator::Engine.routes.draw do
    post "translate" => "translator#translate"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseTranslator::Engine, at: "translator"
  end
end
