# frozen_string_literal: true

DiscourseTranslator::Engine.routes.draw do
  post "/translate" => "translator#translate", :format => :json
end

Discourse::Application.routes.draw { mount ::DiscourseTranslator::Engine, at: "/translator" }
