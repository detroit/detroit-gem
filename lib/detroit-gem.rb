require 'detroit/tool'

module Detroit

  # Create new Gem tool with the specified +options+.
  def Gem(options={})
    Gem.new(options)
  end

  # The Gem tool is used to generate gemspec and gem packages.
  class Gem < Tool

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


    #  A S S E M B L Y  S T A T I O N S

    # Attach package method to package assembly station.
    def station_package
      package
    end

    # Attach install method to install assembly station.
    def station_install
      install
    end

    # Attach release method to release assembly station.
    def station_release
      release
    end

    # Attach reset method to reset assembly station.
    def station_reset
      rest
    end

    # Attach purge method to purge assembly station.
    def station_purge
      purge
    end


    #  S E R V I C E  M E T H O D S

    # Write gemspec if +autospec+ is +true+ and then build the gem.
    def package
      create_gemspec if autospec
      build
    end

    # Create a gem package.
    def build
      trace "gem build #{gemspec}"
      spec    = load_gemspec
      builder = ::Gem::Builder.new(spec)
      package = builder.build
      mkdir_p(pkgdir)
      mv(package, pkgdir)
    end

    # Convert metadata to a gemspec and write to +file+.
    #
    # file - name of gemspec file (defaults to value of #gemspec).
    #
    # Returns [String] file name.
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

    # Push gem package to RubyGems.org (a la Gemcutter).
    #--
    # TODO: Do this programatically instead of shelling out.
    #++
    def push
      if package_files.empty?
        report "No .gem packages found for version {version} at #{pkgdir}."
      else
        package_files.each do |file|
          sh "gem push #{file}"
        end
      end
    end

    #
    alias_method :release, :push

    # Mark package files as outdated.
    def reset
      package_files.each do |f|
        utime(0 ,0, f) 
        report "Reset #{f}"
      end
    end

    # Remove package file(s).
    #--
    # TODO: This is a little loose. Can we be more specific about which
    # gem file(s) to remove?
    #++
    def purge
      package_files.each do |f|
        rm(f)
        report "Removed #{f}"
      end
    end

  private

    #
    def initialize_defaults
      @autospec  = false

      @pkgdir  ||= project.pkg
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
      require 'pom/gemspec'
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

    # TODO: Should we be rescuing this?
    def initialize_requires
      begin
        require 'rubygems'
      rescue LoadError
        $stderr.puts "Could not load `rubygems'."
      end
      # can't do this b/c options not set yet
      #require 'pom/gemspec' if autospec
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

  public

    def self.man_page
      File.dirname(__FILE__)+'/../man/detroit-gem.5'
    end

  end

end
