require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'erb'

require File.dirname(__FILE__) + '/lib/trustcommerce'
require File.dirname(__FILE__) + '/lib/version'

task :default => :test

Rake::TestTask.new(:test) { |t|
  t.libs << 'test'
  t.test_files = Dir.glob('test/*_test.rb')
  t.verbose = true
}

namespace :doc do
  
  Rake::RDocTask.new do |rdoc|
    rdoc.rdoc_dir = 'doc'
    rdoc.title    = "TrustCommerce Subscription Library"
    rdoc.options << '--line-numbers' << '--inline-source'
    rdoc.rdoc_files.include('README')
    rdoc.rdoc_files.include('MIT-LICENSE')
    rdoc.rdoc_files.include('lib/**/*.rb')
  end
  
  task :rdoc => 'doc:readme'
  
  task :refresh => :rerdoc do
    system 'open doc/index.html'
  end

  task :readme do
    require 'support/rdoc/code_info'
    RDoc::CodeInfo.parse('(lib|test)/*.rb')
    
    strip_comments = lambda {|comment| comment.gsub(/^# ?/, '')}
    docs_for       = lambda do |location|
      info = RDoc::CodeInfo.for(location)
      raise RuntimeError, "Couldn't find documentation for `#{location}'" unless info
      strip_comments[info.comment]
    end
    
    open('README', 'w') do |file|
      file.write ERB.new(IO.read('README.erb')).result(binding)
    end
  end
  
  task :deploy => :rerdoc do
    sh %(scp -r doc zackchandler@rubyforge.org:/var/www/gforge-projects/trustcommerce/)
  end
  
end

namespace :site do
  require 'rdoc/markup/simple_markup'
  require 'rdoc/markup/simple_markup/to_html'
  
  readme = lambda { IO.read('README') }

  readme_to_html = lambda do
    handler = SM::ToHtml.new
    handler.instance_eval do
      require 'syntax'
      require 'syntax/convertors/html'
      def accept_verbatim(am, fragment) 
        syntax = Syntax::Convertors::HTML.for_syntax('ruby')
        @res << %(<div class="ruby">#{syntax.convert(fragment.txt, true)}</div>)
      end
    end
    html = SM::SimpleMarkup.new.convert(readme.call, handler)
    html.gsub(%r{\[([\w\s]+)\]\(([\w:/.]+)\)}, '<a href="\2">\1</a>')
  end
  
  desc 'Regenerate the public website page'
  task :build => 'doc:readme' do
    open('site/public/index.html', 'w') do |file|
      erb_data = {}
      erb_data[:readme] = readme_to_html.call
      file.write ERB.new(IO.read('site/index.erb')).result(binding)
    end
  end
  
  task :refresh => :build do
    system 'open site/public/index.html'
  end
  
  desc 'Update the live website'
  task :deploy => :build do
    site_files = FileList['site/public/*']
    sh %(scp #{site_files.join ' '} zackchandler@rubyforge.org:/var/www/gforge-projects/trustcommerce/)
  end
end

namespace :dist do
  
  spec = Gem::Specification.new do |s|
    s.name              = 'trustcommerce'
    s.version           = Gem::Version.new(TrustCommerce::Version)
    s.summary           = 'TrustCommerce Subscription Library'
    s.description       = s.summary
    s.email             = 'zackchandler@depixelate.com'
    s.author            = 'Zack Chandler'
    s.has_rdoc          = true
    s.extra_rdoc_files  = %w(README MIT-LICENSE)
    s.homepage          = 'http://trustcommerce.rubyforge.org'
    s.rubyforge_project = 'trustcommerce'
    s.files             = FileList['Rakefile', 'lib/*.rb', 'support/**/*.rb']
    s.test_files        = Dir['test/*']

    s.rdoc_options  = ['--title', 'TrustCommerce Subscription Library',
                       '--main',  'README',
                       '--line-numbers', '--inline-source']
  end
    
  # Regenerate README before packaging
  task :package => 'doc:readme'
  Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar_gz = true
    pkg.package_files.include('{lib,test,support}/**/*')
    pkg.package_files.include('README')
    pkg.package_files.include('MIT-LICENSE')
    pkg.package_files.include('Rakefile')
  end
  
  desc 'Install with gems'
  task :install => :repackage do
    sh "sudo gem i pkg/#{spec.name}-#{spec.version}.gem"
  end
  
  desc 'Uninstall gem'
  task :uninstall do
    sh "sudo gem uninstall #{spec.name}"
  end
  
  desc 'Reinstall gem'
  task :reinstall => [:uninstall, :install]
  
  task :confirm_release do
    print "Releasing version #{spec.version}. Are you sure you want to proceed? [Yn] "
    abort if STDIN.getc == ?n
  end
  
  desc 'Tag release'
  task :tag do
    svn_root = 'svn+ssh://zackchandler@rubyforge.org/var/svn/trustcommerce'
    sh %(svn cp #{svn_root}/trunk #{svn_root}/tags/rel-#{spec.version} -m "Tag #{spec.name} release #{spec.version}")
  end
  
  desc 'Update changelog to include a release marker'
  task :add_release_marker_to_changelog do
    changelog = IO.read('CHANGELOG')
    changelog.sub!(/^trunk:/, "#{spec.version}:")
    
    open('CHANGELOG', 'w') do |file|
      file.write "trunk:\n\n#{changelog}"
    end
  end
  
  task :commit_changelog do
    sh %(svn ci CHANGELOG -m "Bump changelog version marker for release")
  end
  
  package_name = lambda {|specification| File.join('pkg', "#{specification.name}-#{specification.version}")}
  
  desc 'Push a release to rubyforge'
  task :release => [:confirm_release, :clean, :add_release_marker_to_changelog, :package, :commit_changelog, :tag] do 
    require 'rubyforge'    
    package = package_name[spec]

    rubyforge = RubyForge.new
    rubyforge.login

    version_already_released = lambda do
      releases = rubyforge.config['rubyforge']['release_ids']
      releases.has_key?(spec.name) && releases[spec.name][spec.version]
    end
    
    abort("Release #{spec.version} already exists!") if version_already_released.call

    if release_id = rubyforge.add_release(spec.rubyforge_project, spec.name, spec.version, "#{package}.tar.gz")
      rubyforge.add_file(spec.rubyforge_project, spec.name, release_id, "#{package}.gem")
    else
      puts 'Release failed!'
    end
  end
  
  task :spec do
    puts spec.to_ruby
  end
  
end

task :clean => ['dist:clobber_package', 'doc:clobber_rdoc']
