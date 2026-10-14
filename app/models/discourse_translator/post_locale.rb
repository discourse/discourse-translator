# frozen_string_literal: true

module DiscourseTranslator
  class PostLocale < ActiveRecord::Base
    self.table_name = "discourse_translator_post_locales"

    belongs_to :post

    validates :post_id, presence: true, uniqueness: true
    validates :detected_locale, presence: true
  end
end

# == Schema Information
#
# Table name: discourse_translator_post_locales
#
#  id              :bigint           not null, primary key
#  post_id         :integer          not null
#  detected_locale :string(20)       not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_discourse_translator_post_locales_on_post_id  (post_id) UNIQUE
#
