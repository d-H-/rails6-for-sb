# frozen_string_literal: true

class ActiveStorage::VariantWithRecord
  attr_reader :blob, :variation

  def initialize(blob, variation)
    @blob, @variation = blob, ActiveStorage::Variation.wrap(variation)
  end

  def processed
    process
    self
  end

  def process
    transform_blob { |image| create_or_find_record(image: image) } unless processed?
  end

  def processed?
    record.present?
  end

  def image
    record&.image
  end

  delegate :key, :url, :download, to: :image, allow_nil: true

  alias_method :service_url, :url
  deprecate service_url: :url

  private
    def transform_blob
      blob.open do |input|
        if !blob.image? || blob.content_type.in?(ActiveStorage.web_image_content_types)
          variation.transform(blob, input) do |output|
            yield io: output, filename: blob.filename, content_type: blob.content_type, service_name: blob.service.name
          end
        else
          variation.transform(blob, input, format: "png") do |output|
            yield io: output, filename: "#{blob.filename.base}.png", content_type: "image/png", service_name: blob.service.name
          end
        end
      end
    end

    def create_or_find_record(image:)
      @record =
        ActiveRecord::Base.connected_to(role: ActiveRecord::Base.writing_role) do
          blob.variant_records.create_or_find_by!(variation_digest: variation.digest) do |record|
            record.image.attach(image)
          end
        end
    end

    def record
      @record ||= blob.variant_records.find_by(variation_digest: variation.digest)
    end
end
