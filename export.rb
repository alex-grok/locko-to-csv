%w(csv json ostruct fileutils date).each(&method(:require))

module Locko

  TMP_FOLDER = '.tmp'

  class Exporter

    class << self
      def to_csv(file_name, arr, mode: 'w')
        CSV.open("#{file_name}.csv", mode) { |csv| csv << arr }
      end
    end

    attr_reader :lckexp_file_name

    def lckexp
      lckexp = Dir.glob(File.join('*.lckexp'))[0]
      raise 'Put *.lckexp file to the same with this ruby script folder' unless lckexp
      lckexp
    end

    def initialize
      @lckexp_file_name = lckexp.sub(/\.lckexp\z/, '')
    end

    def items
      @items ||= begin
        system("unzip -o ./#{lckexp} -d #{TMP_FOLDER}")
        Dir.glob(File.join(TMP_FOLDER, '**', '*.item'))
      end
    end

    def data_header
      @data_header ||= items.map { |i| Item.new(i).fields_names }.flatten.compact.uniq
    end

    def process
      self.class.to_csv lckexp_file_name, ['title'] + data_header + ['custom fields']
      items.each { |i| Item.new(i).export(lckexp_file_name, data_header) }
      FileUtils.rm_rf("./#{TMP_FOLDER}")
    end

  end

  class Item

    attr_reader :json

    def initialize(path)
      @json = JSON.parse File.read(path), object_class: OpenStruct
    end

    def title
      json.title
    end

    def data
      json.data
    end

    def fields
      @fields ||= data.fields
    end

    def fields_names
      fields.to_h.keys
    end

    def custom_fields
      @custom_fields ||= data.customFields || []
    end

    def custom_fields_data
      "#{custom_fields.map { |cf| "#{cf.label}: #{cf.value}" }.join("\n")}"
    end

    def attachments?
      json.type.to_s == '9001'
    end

    def attachments
      Dir.glob(File.join(TMP_FOLDER, '**', json.uuid, '*'))
    end

    def export(file_name, data_header)
      if attachments?
        if attachments.size > 0
          attachment_folder = "#{file_name}/#{title}"
          FileUtils.mkdir_p(attachment_folder)
          attachments.each { |a| FileUtils.cp a, attachment_folder }
        end
      else
        Exporter.to_csv file_name, [title] + data_header.map(&method(:get_value)) + [custom_fields_data], mode: 'ab'
      end
    end

    def get_value(v)
      val = fields.send(v) rescue nil
      if v.to_s.include?('Date') && val
        Time.at(val).to_datetime.next_year(31).strftime('%F')
      else
        val
      end
    end
  end
end

Locko::Exporter.new.process
