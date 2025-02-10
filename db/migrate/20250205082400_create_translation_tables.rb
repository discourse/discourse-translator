# frozen_string_literal: true

class CreateTranslationTables < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_translator_topic_locales do |t|
      t.integer :topic_id, null: false
      t.string :detected_locale, limit: 20, null: false
      t.timestamps
    end

    create_table :discourse_translator_topic_translations do |t|
      t.integer :topic_id, null: false
      t.string :locale, null: false
      t.text :translation, null: false
      t.timestamps
    end

    create_table :discourse_translator_post_locales do |t|
      t.integer :post_id, null: false
      t.string :detected_locale, limit: 20, null: false
      t.timestamps
    end

    create_table :discourse_translator_post_translations do |t|
      t.integer :post_id, null: false
      t.string :locale, null: false
      t.text :translation, null: false
      t.timestamps
    end
  end
end
