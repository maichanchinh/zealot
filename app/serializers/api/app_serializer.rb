# frozen_string_literal: true

class Api::AppSerializer < ApplicationSerializer
  attributes :id, :name, :recently_release,:total_schemes, :total_channels, :total_releases

  has_many :schemes
end
