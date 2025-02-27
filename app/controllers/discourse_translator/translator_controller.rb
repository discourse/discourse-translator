# frozen_string_literal: true

module ::DiscourseTranslator
  class TranslatorController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in

    def translate
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
          "DiscourseTranslator::#{SiteSetting.translator_provider}".constantize.translate(post)
        if post.is_first_post?
          _, title_translation =
            "DiscourseTranslator::#{SiteSetting.translator_provider}".constantize.translate(
              post.topic,
            )
          title_json = { title_translation: title_translation }
        end
        render json: { translation: translation, detected_lang: detected_lang }.merge(title_json),
               status: 200
      rescue ::DiscourseTranslator::TranslatorError => e
        render_json_error e.message, status: 422
      end
    end
  end
end
