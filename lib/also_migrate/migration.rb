module AlsoMigrate
  module Migration
    def method_missing_with_also_migrate(method, *arguments, &block)
      args = Marshal.load(Marshal.dump(arguments))
      return_value = method_missing_without_also_migrate(method, *arguments, &block)

      supported = [
        :add_column, :add_index, :add_timestamps, :change_column,
        :change_column_default, :change_table, :create_table,
        :drop_table, :remove_column, :remove_columns,
        :remove_timestamps, :rename_column, :rename_table
      ]

      if !args.empty? && supported.include?(method)
        connection = ActiveRecord::Base.connection
        table_name = ActiveRecord::Migrator.proper_table_name(args[0])
        
        # Find models
        (::AlsoMigrate.configuration || []).each do |config|
          next unless config[:source].to_s == table_name
      
          # Don't change ignored columns
          [ config[:ignore] ].flatten.compact.each do |column|
            next if args.include?(column) || args.include?(column.intern)
          end

          # Run migration
          if method == :create_table
            ActiveRecord::Migrator::AlsoMigrate.create_tables(config)
          elsif method == :add_index && !config[:indexes].nil?
            next
          else
            if method == :add_index and args[2].present? and args[2][:name].present?
              if args[2][:name].length >= 58
                args[2][:name] = "#{args[2][:name][0..-6]}_also".to_sym
              else
                args[2][:name] = "#{args[2][:name]}_also".to_sym
              end
            end
            [ config[:destination] ].flatten.compact.each do |table|
              if connection.table_exists?(table)
                args[0] = table
                begin
                  connection.send(method, *args, &block)
                rescue Exception => e
                  puts "(also_migrate warning) #{e.message}"
                end
              end
            end
          end
        end
      end
      
      return return_value
    end

    def self.included(base)
      base.class_eval do
        alias_method :method_missing_without_also_migrate, :method_missing
        alias_method :method_missing, :method_missing_with_also_migrate
      end
    end
  end
end

