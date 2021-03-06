require 'detroit-standard'

module Detroit

  # The Gem tool is used to generate gemspec and gem packages
  # for ruby projects.
  #
  # This tool was designed for the standard toolchain supporting
  # the following stations:
  #
  # * package
	# * install
	# * release
	#	* reset
  # * purge
  # 
  class Gem < Tool

    # Designed for the Standard assembly.
    #
    # @!parse
    #   include Standard
    #
    assembly Standard

    # RubyGems is a tool for packaging Ruby projects.
    include RubyUtils

    # Location of man_page for tool.
    MANPAGE = File.dirname(__FILE__) + '/../man/detroit-gem.5'

    #
    def prerequisite
      require 'rubygems'
      require 'rubygems/package'
    end

    # The .gemspec filename (default looks-up `.gemspec` or `name.gemspec` file).
    attr_accessor :gemspec

    # True or false whether to write gemspec from project metadata (default is `false`).
    attr_accessor :autospec

    # Package directory (defaults to `pkg`).
    # Location of packages. This defaults to Project#pkg.
    attr_accessor :pkgdir

    # Whether to install the gem.
    attr_writer :install

    # Whether to install the gem (default `false`).
    def install?
      @install
    end

    # What rvm gemset to install in if installing.
    #attr_accessor :gemset

    # Version to release. Defaults to current version.
    attr :version

    # Additional options to pass to gem command.
    #attr :options

    # Write gemspec if +autospec+ is +true+ and then build the gem.
    def package
      create_gemspec if autospec   # TODO: should autospec be a generate phase?
      build
    end

    # Create a gem package.
    def build
      trace "gem build #{gemspec}"
      spec = load_gemspec
      package = ::Gem::Package.build(spec)
      mkdir_p(pkgdir) unless File.directory?(pkgdir)
      mv(package, pkgdir)
    end

    # Convert metadata to a gemspec and write to +file+.
    #
    # @param [String] file
    #   Name of gemspec file (defaults to value of #gemspec).
    #
    # @return [String] The file name.
    def spec(file=nil)
      create_gemspec(file)
    end

    #
    def install
      return unless install?
      package_files.each do |file|
        sh "gem install --no-rdoc --no-ri #{file}"
      end
    end

    # TODO: Gem push programatically instead of shelling out.

    # Push gem package to RubyGems.org (a la Gemcutter).
    def push
      if package_files.empty?
        report "No .gem packages found for version {version} at #{pkgdir}."
      else
        package_files.each do |file|
          sh "gem push #{file}"
        end
      end
    end

    # Same as #push.
    def release
      push
    end

    # Mark package files as outdated.
    def reset
      package_files.each do |f|
        utime(0 ,0, f) 
        report "Reset #{f}"
      end
    end

    # Remove package file(s).
    #
    # @todo This code is a little loose. Can it be more specific about which
    #       gem file(s) to remove?
    #
    def purge
      package_files.each do |f|
        rm(f)
        report "Removed #{f}"
      end
    end

    #
    def assemble?(station, options={})
      return true if station == :package
      return true if station == :install
      return true if station == :release
      return true if station == :reset
      return true if station == :purge
      return false
    end

  private

    # Initialize attribute defaults.
    def initialize_defaults
      super

      @autospec  = false

      @pkgdir  ||= (root + 'pkg').to_s #|| project.pkg
      @gemspec ||= lookup_gemspec

      @version = project.metadata.version
    end

    #
    def package_files
      Pathname.new(pkgdir).glob("*-#{version}.gem")
    end

    # Create gemspec if +autospec+ is +true+.
    def prepackage
      create_gemspec if autospec
    end

    # Create a gemspec file from project metadata.
    def create_gemspec(file=nil)
      file = gemspec if !file
      #require 'gemdo/gemspec'
      yaml = project.to_gemspec.to_yaml
      File.open(file, 'w') do |f|
        f << yaml
      end
      status File.basename(file) + " updated."
      return file
    end

    # Lookup gemspec file. If not found returns default path.
    #
    # Returns String of file path.
    def lookup_gemspec
      dot_gemspec = (project.root + '.gemspec').to_s
      if File.exist?(dot_gemspec)
        dot_gemspec.to_s
      else
        project.metadata.name + '.gemspec'
      end
    end

    # Load gemspec file.
    #
    # Returns a ::Gem::Specification.
    def load_gemspec
      file = gemspec
      if yaml?(file)
        ::Gem::Specification.from_yaml(File.new(file))
      else
        ::Gem::Specification.load(file)
      end
    end

    # If the gemspec a YAML gemspec?
    def yaml?(file)
      line = open(file) { |f| line = f.gets }
      line.index "!ruby/object:Gem::Specification"
    end

    ## Require rubygems library
    #def require_rubygems
    #  begin
    #    require 'rubygems/specification'
    #    ::Gem::manage_gems
    # rescue LoadError
    #    raise LoadError, "RubyGems is not installed."
    # end
    #end

  end

end
