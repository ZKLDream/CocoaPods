module Pod
  class Sandbox
    # Provides support for managing a header directory. It also keeps track of
    # the header search paths.
    #
    class HeadersStore
      SEARCH_PATHS_KEY = Struct.new(:platform_name, :target_name, :use_modular_headers)

      # @return [Pathname] the absolute path of this header directory.
      #
      def root
        sandbox.headers_root + @relative_path
      end

      # @return [Sandbox] the sandbox where this header directory is stored.
      #
      attr_reader :sandbox

      # @param  [Sandbox] @see sandbox
      #
      # @param  [String] relative_path
      #         the relative path to the sandbox root and hence to the Pods
      #         project.
      #
      # @param  [Symbol] visibility_scope
      #         the header visibility scope to use in this store. Can be `:private` or `:public`.
      #
      def initialize(sandbox, relative_path, visibility_scope)
        @sandbox       = sandbox
        @relative_path = relative_path
        @search_paths  = []
        @search_paths_cache = {}
        @visibility_scope = visibility_scope
      end

      # @param  [Platform] platform
      #         the platform for which the header search paths should be
      #         returned.
      #
      # @param  [String] target_name
      #         the target for which the header search paths should be
      #         returned. Can be `nil` in which case all headers that match the platform
      #         will be returned.
      #
      # @param  [Boolean] use_modular_headers
      #         whether the search paths generated should use modular (stricter) style.
      #
      # @return [Array<String>] All the search paths of the header directory in
      #         xcconfig format. The paths are specified relative to the pods
      #         root with the `${PODS_ROOT}` variable.
      #
      def search_paths(platform, target_name = nil, use_modular_headers = false)
        key = SEARCH_PATHS_KEY.new(platform.name, target_name, use_modular_headers)
        return @search_paths_cache[key] if @search_paths_cache.key?(key)
        search_paths = @search_paths.select do |entry|
          matches_platform = entry[:platform] == platform.name
          matches_target = target_name.nil? || (entry[:path].basename.to_s == target_name)
          matches_platform && matches_target
        end
        headers_dir = root.relative_path_from(sandbox.root).dirname
        @search_paths_cache[key] = search_paths.uniq.flat_map do |entry|
          path = "${PODS_ROOT}/#{headers_dir}/#{entry[:path]}"
          paths = [path]
          paths.push("#{path}/#{entry[:path].basename}") if !use_modular_headers && @visibility_scope == :public
          paths
        end
      end

      # Removes the directory as it is regenerated from scratch during each
      # installation.
      #
      # @return [void]
      #
      def implode!
        root.rmtree if root.exist?
      end

      #-----------------------------------------------------------------------#

      public

      # @!group Adding headers

      # Adds headers to the directory.
      #
      # @param  [Pathname] namespace
      #         the path where the header file should be stored relative to the
      #         headers directory.
      #
      # @param  [Array<Pathname>] relative_header_paths
      #         the path of the header file relative to the Pods project
      #         (`PODS_ROOT` variable of the xcconfigs).
      #
      # @note   This method does _not_ add the files to the search paths.
      #
      # @return [Array<Pathname>]
      #
      def add_files(namespace, relative_header_paths)
        relative_header_paths.map do |relative_header_path|
          add_file(namespace, relative_header_path)
        end
      end

      # Adds a header to the directory.
      #
      # @param  [Pathname] namespace
      #         the path where the header file should be stored relative to the
      #         headers directory.
      #
      # @param  [Pathname] relative_header_path
      #         the path of the header file relative to the Pods project
      #         (`PODS_ROOT` variable of the xcconfigs).
      #
      # @note   This method does _not_ add the file to the search paths.
      #
      # @return [Pathname]
      #
      def add_file(namespace, relative_header_path)
        namespaced_path = root + namespace
        namespaced_path.mkpath unless File.exist?(namespaced_path)

        absolute_source = (sandbox.root + relative_header_path)
        source = absolute_source.relative_path_from(namespaced_path)
        FileUtils.ln_sf(source, namespaced_path)
        namespaced_path + relative_header_path.basename
      end

      # Adds an header search path to the sandbox.
      #
      # @param  [Pathname] path
      #         the path tho add.
      #
      # @param  [String] platform
      #         the platform the search path applies to
      #
      # @return [void]
      #
      def add_search_path(path, platform)
        @search_paths << { :platform => platform.name, :path => (Pathname.new(@relative_path) + path) }
      end

      #-----------------------------------------------------------------------#
    end
  end
end
