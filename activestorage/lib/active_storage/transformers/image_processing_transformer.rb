# frozen_string_literal: true

module ActiveStorage
  module Transformers
    class ImageProcessingTransformer < Transformer
      def self.accept?(blob)
        ActiveStorage.variable_content_types.include?(blob.content_type)
      end

      def process(file, format:)
        processor.
          source(file).
          loader(page: 0).
          convert(format).
          apply(operations).
          call
      end

      private
        def processor
          require "image_processing" unless defined?(ImageProcessing)
          ImageProcessing.const_get(ActiveStorage.variant_processor.to_s.camelize)
        end

        def operations
          transformations.each_with_object([]) do |(name, argument), list|
            if name.to_s == "combine_options"
              ActiveSupport::Deprecation.warn <<~WARNING.squish
                Active Storage's ImageProcessing transformer doesn't support :combine_options,
                as it always generates a single ImageMagick command. Passing :combine_options will
                not be supported in Rails 6.1.
              WARNING

              list.concat argument.keep_if { |key, value| value.present? }.to_a
            elsif argument.present?
              list << [ name, argument ]
            end
          end
        end
    end
  end
end
