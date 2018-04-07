require "json"
require "./user"

module AvalancheMQ
  class UserStore
    def initialize(@data_dir : String, @log : Logger)
      @users = Hash(String, User).new
      load!
    end

    def []?(name)
      @users[name]?
    end

    def size
      @users.size
    end

    def create(name, password, save = true)
      return if @users.has_key?(name)
      user = User.new(name, password)
      @users[name] = user
      save! if save
      user
    end

    def delete(name) : User?
      if user = @users.delete name
        user.delete
        save!
        user
      end
    end

    def close
      @users.each_value &.close
      save!
    end

    def to_json(json : JSON::Builder)
      @users.values.to_json(json)
    end

    private def load!
      path = File.join(@data_dir, "users.json")
      if File.exists? path
        @log.debug "Loading users from file"
        File.open(path) do |f|
          Array(User).from_json(f) do |user|
            @users[user.name] = user
          end
        end
      else
        @log.debug "Loading default users"
        create("guest", "guest", save: false)
        save!
      end
      @log.debug("#{@users.size} users loaded")
    end

    private def save!
      @log.debug "Saving users to file"
      tmpfile = File.join(@data_dir, "users.json.tmp")
      File.open(tmpfile, "w") { |f| self.to_json(f) }
      File.rename tmpfile, File.join(@data_dir, "users.json")
    end
  end
end