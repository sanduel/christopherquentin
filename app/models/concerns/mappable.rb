module Mappable
  extend ActiveSupport::Concern

  included do
    scope :mapped, -> { where.not(latitude: nil, longitude: nil) }
  end

  class_methods do
    def default_pin_color
      raise NotImplementedError, "#{name} must define .default_pin_color"
    end

    def default_pin_icon
      raise NotImplementedError, "#{name} must define .default_pin_icon"
    end

    def map_category
      raise NotImplementedError, "#{name} must define .map_category"
    end
  end

  def effective_pin_color
    pin_color.presence || self.class.default_pin_color
  end

  def effective_pin_icon
    pin_icon.presence || self.class.default_pin_icon
  end
end
