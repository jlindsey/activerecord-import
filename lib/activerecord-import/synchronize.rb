module ActiveRecord # :nodoc:
  class Base # :nodoc:
      
    # Synchronizes the passed in ActiveRecord instances with data
    # from the database. This is like calling reload on an individual
    # ActiveRecord instance but it is intended for use on multiple instances. 
    # 
    # This uses one query for all instance updates and then updates existing
    # instances rather sending one query for each instance
    #
    # == Examples
    # # Synchronizing existing models by matching on the primary key field
    # posts = Post.find_by_author("Zach")
    # <.. out of system changes occur to change author name from Zach to Zachary..>
    # Post.synchronize posts
    # posts.first.author # => "Zachary" instead of Zach
    # 
    # # Synchronizing using custom key fields
    # posts = Post.find_by_author("Zach")
    # <.. out of system changes occur to change the address of author 'Zach' to 1245 Foo Ln ..>
    # Post.synchronize posts, [:name] # queries on the :name column and not the :id column
    # posts.first.address # => "1245 Foo Ln" instead of whatever it was
    #
    def self.synchronize(instances, keys=[self.primary_key])
      return if instances.empty?

      conditions = {}
      order = ""
      
      key_values = keys.map { |key| instances.map(&"#{key}".to_sym) }
      keys.zip(key_values).each { |key, values| conditions[key] = values }
      order = keys.map{ |key| "#{key} ASC" }.join(",")

      klass = instances.first.class
      sql = klass.scoped.where(conditions).order(order).to_sql
      fresh_attributes = ActiveRecord::Base.connection.select_all sql
      
      sorted_attributes = fresh_attributes.inject({}) do |sum, hash|
        h = HashWithIndifferentAccess.new hash
        key_ary = keys.map do |k|
          col = klass.columns.find { |c| c.name.to_sym == k }
          col.type_cast h[k]
        end
        sum[key_ary] = h
        sum
      end

      instances.each do |instance|
        key_ary = keys.map { |k| instance.send(k) }
        matched_hash = sorted_attributes[key_ary]

        if matched_hash
          sorted_attributes.delete key_ary

          instance.clear_aggregation_cache
          instance.clear_association_cache
          instance.instance_variable_set '@attributes', matched_hash
        end
      end
    end

    # See ActiveRecord::ConnectionAdapters::AbstractAdapter.synchronize
    def synchronize(instances, key=[ActiveRecord::Base.primary_key])
      self.class.synchronize(instances, key)
    end
  end
end
