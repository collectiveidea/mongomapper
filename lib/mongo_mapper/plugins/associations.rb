# encoding: UTF-8
module MongoMapper
  module Plugins
    module Associations
      module ClassMethods
        def inherited(subclass)
          subclass.associations = associations.dup
          super
        end

        def belongs_to(association_id, options={}, &extension)
          create_association(:belongs_to, association_id, options, &extension)
        end

        def many(association_id, options={}, &extension)
          create_association(:many, association_id, options, &extension)
        end

        def one(association_id, options={}, &extension)
          create_association(:one, association_id, options, &extension)
        end

        def associations
          @associations ||= HashWithIndifferentAccess.new
        end

        def associations=(hash)
          @associations = hash
        end

        private
          def create_association(type, name, options, &extension)
            association = Associations::Base.new(type, name, options, &extension)
            associations[association.name] = association

            if association.one? || association.belongs_to?
              define_method(association.name) do
                proxy = get_proxy(association)
                proxy.nil? ? nil : proxy
              end

              define_method("#{association.name}=") do |value|
                proxy = get_proxy(association)

                if proxy.nil? || proxy.target != value
                  proxy = build_proxy(association)
                end

                proxy.replace(value)
                value
              end

              define_method("#{association.name}?") do
                get_proxy(association).present?
              end

              if association.one?
                define_method("build_#{association.name}") do |*args|
                  get_proxy(association).build(*args)
                end

                define_method("create_#{association.name}") do |*args|
                  get_proxy(association).create(*args)
                end

                define_method("create_#{association.name}!") do |*args|
                  get_proxy(association).create!(*args)
                end
              end
            else
              define_method(association.name) do
                get_proxy(association)
              end

              define_method("#{association.name}=") do |value|
                get_proxy(association).replace(value)
                value
              end

            end

            if association.options[:dependent] && association.many? && !association.embeddable?
              after_destroy do |doc|
                case association.options[:dependent]
                  when :destroy
                    doc.get_proxy(association).destroy_all
                  when :delete_all
                    doc.get_proxy(association).delete_all
                  when :nullify
                    doc.get_proxy(association).nullify
                end
              end
            end
            association
          end

      end

      module InstanceMethods
        def associations
          self.class.associations
        end

        def embedded_associations
          associations.values.select(&:embeddable?)
        end

        def build_proxy(association)
          proxy = association.proxy_class.new(self, association)
          self.instance_variable_set(association.ivar, proxy)

          proxy
        end

        def get_proxy(association)
          unless proxy = self.instance_variable_get(association.ivar)
            proxy = build_proxy(association)
          end
          proxy
        end

        def save_to_collection(options={})
          super if defined?(super)
          associations.each do |association_name, association|
            proxy = get_proxy(association)
            proxy.save_to_collection(options) if proxy.proxy_respond_to?(:save_to_collection)
          end
        end
      end
    end
  end
end
