# name: discourse-translator
# about: Provides inline translation of posts.
# version: 0.1.3
# authors: Alan Tan
# url: https://github.com/tgxworld/discourse-translator

enabled_site_setting :translator_enabled
register_asset "stylesheets/common/post.scss"

after_initialize do
  module ::DiscourseTranslator
    PLUGIN_NAME = "discourse_translator".freeze
    DETECTED_LANG_CUSTOM_FIELD = 'post_detected_lang'.freeze
    TRANSLATED_CUSTOM_FIELD = 'translated_text'.freeze

    autoload :Microsoft, "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/microsoft"
    autoload :Google, "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/google"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseTranslator
    end
  end

  require_dependency "application_controller"
  class DiscourseTranslator::TranslatorController < ::ApplicationController
    before_filter :ensure_logged_in

    def translate
      raise PluginDisabled if !SiteSetting.translator_enabled
      RateLimiter.new(current_user, "translate_post", 3, 1.minute).performed! unless current_user.staff?

      params.require(:post_id)
      post = Post.find(params[:post_id].to_i)

      begin
        detected_lang, translation = "DiscourseTranslator::#{SiteSetting.translator}".constantize.translate(post)
        render json: { translation: translation, detected_lang: detected_lang }, status: 200
      rescue ::DiscourseTranslator::TranslatorError => e
        render_json_error e.message, status: 422
      end
    end
  end

  Post.register_custom_field_type(::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD, :json)

  require_dependency "post"
  class ::Post < ActiveRecord::Base
    before_update :clear_translator_custom_fields, if: :raw_changed?

    private

    def clear_translator_custom_fields
      self.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = nil
      self.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] = {}
    end
  end

  require_dependency "jobs/base"
  module ::Jobs
    class DetectTranslation < Jobs::Base
      def execute(args)
        post = Post.find(args[:post_id])

        DistributedMutex.synchronize("detect_translation_#{post.id}") do
          "DiscourseTranslator::#{SiteSetting.translator}".constantize.detect(post)
          post.save_custom_fields unless post.custom_fields_clean?
          post.publish_change_to_clients! :revised
        end
      end
    end
  end

  def post_process(post)
    return if !SiteSetting.translator_enabled
    Jobs.enqueue(:detect_translation, { post_id: post.id })
  end
  listen_for :post_process

  TopicView.add_post_custom_fields_whitelister do |user|
    [::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]
  end

  require_dependency "post_serializer"
  class ::PostSerializer
    attributes :can_translate

    def can_translate
      return false if !SiteSetting.translator_enabled

      detected_lang = post_custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]

      if !detected_lang
        Jobs.enqueue(:detect_translation, { post_id: object.id })
        false
      else
        detected_lang != "DiscourseTranslator::#{SiteSetting.translator}::SUPPORTED_LANG".constantize[I18n.locale]
      end
    end

  end

  DiscourseTranslator::Engine.routes.draw do
    post "translate" => "translator#translate"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseTranslator::Engine, at: "translator"
  end
end
