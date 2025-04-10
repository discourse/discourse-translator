# frozen_string_literal: true

module DiscourseTranslator
  class InlineTranslation
    def self.effective_locale
      if LocaleMatcher.user_locale_is_default? || LocaleMatcher.user_locale_in_target_languages?
        I18n.locale
      else
        SiteSetting.default_locale
      end
    end

    SHOW_ORIGINAL_COOKIE = "discourse-translator-show-original"

    def inject(plugin)
      plugin.register_anonymous_cache_key :showoriginal do
        @request.cookies[SHOW_ORIGINAL_COOKIE].present? ? "1" : "0"
      end

      # since locales are eager loaded but translations may not,
      # always return early if topic and posts are in the user's effective_locale.
      # this prevents the need to load translations.

      plugin.register_modifier(:basic_post_serializer_cooked) do |cooked, serializer|
        if show_translation?(serializer.object, serializer.scope)
          serializer.object.translation_for(InlineTranslation.effective_locale).presence
        else
          cooked
        end
      end

      plugin.register_modifier(:topic_serializer_fancy_title) do |fancy_title, serializer|
        if show_translation?(serializer.object, serializer.scope)
          serializer
            .object
            .translation_for(InlineTranslation.effective_locale)
            .presence
            &.then { |t| Topic.fancy_title(t) }
        else
          fancy_title
        end
      end

      plugin.register_modifier(:topic_view_serializer_fancy_title) do |fancy_title, serializer|
        if show_translation?(serializer.object.topic, serializer.scope)
          serializer
            .object
            .topic
            .translation_for(InlineTranslation.effective_locale)
            .presence
            &.then { |t| Topic.fancy_title(t) }
        else
          fancy_title
        end
      end

      plugin.add_to_serializer(:basic_post, :is_translated) do
        SiteSetting.experimental_inline_translation &&
          !object.locale_matches?(InlineTranslation.effective_locale) &&
          !scope&.request&.cookies&.key?(SHOW_ORIGINAL_COOKIE) &&
          object.translation_for(InlineTranslation.effective_locale).present?
      end

      plugin.add_to_serializer(:basic_post, :detected_language) do
        if SiteSetting.experimental_inline_translation && object.detected_locale.present?
          LocaleToLanguage.get_language(object.detected_locale)
        end
      end

      plugin.add_to_serializer(:topic_view, :show_translation_toggle) do
        return false if !SiteSetting.experimental_inline_translation
        # either the topic or any of the posts has a translation
        # also, check the locale first as it is cheaper than loading translation
        (
          !object.topic.locale_matches?(InlineTranslation.effective_locale) &&
            object.topic.translation_for(InlineTranslation.effective_locale).present?
        ) ||
          (
            object.posts.any? do |post|
              !post.locale_matches?(InlineTranslation.effective_locale) &&
                post.translation_for(InlineTranslation.effective_locale).present?
            end
          )
      end

      plugin.register_topic_preloader_associations(:content_locale) do
        SiteSetting.translator_enabled && SiteSetting.experimental_inline_translation
      end
      plugin.register_topic_preloader_associations(:translations) do
        SiteSetting.translator_enabled && SiteSetting.experimental_inline_translation
      end

      # categories

      # this hunk works
      plugin.register_modifier(:site_category_serializer_name) do |name, serializer|
        if !SiteSetting.experimental_inline_translation ||
             serializer.object.locale_matches?(InlineTranslation.effective_locale) ||
             serializer.scope&.request&.params&.[]("show") == "original"
          name
        else
          serializer.object.translation_for(InlineTranslation.effective_locale).presence
        end
      end

      # unsure about this one which should essentially be the "same" as site_category_serializer_name
      # but it makes use of an existing modifier
      # plugin.register_modifier(:site_all_categories_cache_query) do |query, site|
      #   current_locale = InlineTranslation.effective_locale.to_s.gsub("_", "-")
      #
      #   query =
      #     query.joins(
      #       "LEFT JOIN discourse_translator_category_translations translations ON
      # translations.category_id = categories.id AND translations.locale = '#{current_locale}'",
      #     )
      #
      #   # a new select that keeps all existing columns but overrides the name
      #   # and remove any explicit selection of categories.name if it exists
      #   # very brittle
      #   original_select =
      #     query.select_values.empty? ? ["categories.*", "t.slug topic_slug"] : query.select_values
      #   filtered_select = original_select.reject { |s| s.include?("categories.name") }
      #
      #   query =
      #     query.unscope(:select).select(
      #       *filtered_select,
      #       "COALESCE(translations.translation, categories.name) AS name",
      #     )
      #
      #   query
      # end

      # tags

      plugin.register_modifier(:topic_tags_all_tags) do |tags|
        tags = tags.includes(:content_locale) if SiteSetting.experimental_inline_translation

        if SiteSetting.experimental_inline_translation &&
             LocaleMatcher.user_locale_in_target_languages?
          locale = InlineTranslation.effective_locale.to_s.gsub("_", "-")
          tags =
            tags
              .includes(:translations)
              .references(:translations)
              .where(translations: { locale: [nil, locale] })
        end
        tags
      end

      plugin.register_modifier(:topic_tags_serializer_name) do |tags|
        tags.map do |tag|
          if !SiteSetting.experimental_inline_translation ||
               !LocaleMatcher.user_locale_in_target_languages?
            tag.name
          else
            tag.translation_for(InlineTranslation.effective_locale) || tag.name
          end
        end
      end

      plugin.register_modifier(:sidebar_tag_serializer_name) do |name, serializer|
        if !SiteSetting.experimental_inline_translation ||
             serializer.object.locale_matches?(InlineTranslation.effective_locale) ||
             serializer.scope&.request&.params&.[]("show") == "original"
          name
        else
          serializer.object.translation_for(InlineTranslation.effective_locale).presence
        end
      end

      # this implementation is an alternative to the `top_tags_query` below
      # but likely not as performant
      plugin.register_modifier(:topic_list_tags) do |tag_names|
        # loop through each tag name and search for the tag
        # then get the translation for the tag
      end

      plugin.register_modifier(:top_tags_query) do |scope_category_ids, filter_sql, limit|
        current_locale = I18n.locale.to_s.sub("_", "-")

        query = <<~SQL
          SELECT COALESCE(translations.translation, tags.name) AS tag_name,
                 SUM(stats.topic_count) AS sum_topic_count
          FROM category_tag_stats stats
          JOIN tags ON stats.tag_id = tags.id AND stats.topic_count > 0
          LEFT JOIN discourse_translator_tag_translations translations
            ON translations.tag_id = tags.id AND translations.locale = '#{current_locale}'
          WHERE stats.category_id in (#{scope_category_ids.join(",")})
          #{filter_sql}
          GROUP BY COALESCE(translations.translation, tags.name)
          ORDER BY sum_topic_count DESC, tag_name ASC
          LIMIT #{limit}
        SQL

        DB.query(query)
      end

      # plugin.register_modifier(:tag_serializer_name) { |name, serializer| "tag_serializer_name" }
    end

    def show_translation?(translatable, scope)
      SiteSetting.experimental_inline_translation &&
        !translatable.locale_matches?(InlineTranslation.effective_locale) &&
        !scope&.request&.cookies&.key?(SHOW_ORIGINAL_COOKIE)
    end
  end
end
