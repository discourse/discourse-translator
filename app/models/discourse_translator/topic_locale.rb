# frozen_string_literal: true

module DiscourseTranslator
  class TopicLocale < ActiveRecord::Base
    self.table_name = "discourse_translator_topic_locales"

    belongs_to :topic

    validates :topic_id, presence: true, uniqueness: true
    validates :detected_locale, presence: true
  end
end

# == Schema Information
#
# Table name: discourse_translator_topic_locales
#
#  id              :bigint           not null, primary key
#  topic_id        :integer          not null
#  detected_locale :string(20)       not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
