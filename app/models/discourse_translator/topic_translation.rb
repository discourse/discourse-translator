# frozen_string_literal: true

module DiscourseTranslator
  class TopicTranslation < ActiveRecord::Base
    self.table_name = "discourse_translator_topic_translations"

    belongs_to :topic

    validates :topic_id, presence: true
    validates :locale, presence: true
    validates :translation, presence: true
    validates :locale, uniqueness: { scope: :topic_id }
  end
end

# == Schema Information
#
# Table name: discourse_translator_topic_translations
#
#  id          :bigint           not null, primary key
#  topic_id    :integer          not null
#  locale      :string           not null
#  translation :text             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  idx_on_topic_id_locale_70b2f83213  (topic_id,locale) UNIQUE
#
