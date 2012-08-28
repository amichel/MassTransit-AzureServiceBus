# Copyright Henrik Feldt 2012
require 'albacore' # gem install albacore
require 'fileutils' #in ruby core
require 'semver' #gem install semver2
require_relative 'build_support/environment'

def conf_assert
  raise "You have to call ':release' or ':debug' to run this task" unless ENV['CONFIGURATION']
end

task :ensure_account_details do
  targ = 'src/MassTransit.Transports.AzureServiceBus.Tests/Framework/AccountDetails.cs'
  unless File.exists? targ then ; FileUtils.cp 'build_support/AccountDetails.cs', targ ; end
  targ = 'src/MassTransit.Async/AccountDetails.fs'
  unless File.exists? targ then ; FileUtils.cp 'build_support/AccountDetails.fs', targ ; end
  targ = 'src/PerformanceTesting/MassTransit.AzurePerformance/ServiceConfiguration.Cloud.cscfg'
  unless File.exists? targ then ; FileUtils.cp 'build_support/ServiceConfiguration.Cloud.cscfg', targ ; end
end

desc "Update the common version information for the build. You can call this task without building."
assemblyinfo :global_version => [:versioning] do |asm|
  # Assembly file config
  asm.product_name = 'MassTransit.Transports.AzureServiceBus'
  asm.version = FORMAL_VERSION
  asm.file_version = FORMAL_VERSION
  asm.custom_attributes :AssemblyInformationalVersion => "#{BUILD_VERSION}",
    :ComVisibleAttribute => false,
    :CLSCompliantAttribute => false
  asm.copyright = 'Henrik Feldt 2012'
  asm.output_file = 'src/SolutionVersion.cs'
  asm.namespaces "System", "System.Reflection", "System.Runtime.InteropServices", "System.Security"
end

desc "Ensure that all NuGet packages are here"
task :ensure_packages do
  Dir.glob("./src/**/packages.config") do |cfg|
    sh %Q[src/.nuget/NuGet.exe install "#{cfg}" -o "src/packages"] do |ok, res|
      puts (res.inspect) unless ok
    end
  end
end

desc "Compile Solution"
msbuild :compile => [:ensure_packages, :ensure_account_details, :global_version] do |msb|
  msb.solution = 'src/MassTransit-AzureServiceBus.sln'
  msb.properties :Configuration => CONFIGURATION
  msb.targets    :Build
  msb.verbosity = "minimal"
end

desc "Run Tests"
nunit :test => [:ensure_account_details, :release, :compile] do |n|
  conf_assert
  asms = Dir.glob("#{File.dirname(__FILE__)}/src/MassTransit.*.Tests/bin/#{CONFIGURATION}/*.Tests.dll")
  puts "Running nunit with assemblies: #{asms.inspect}"
  n.command = Dir.glob("#{File.dirname(__FILE__)}/src/packages/NUnit.Runners*/Tools/nunit-console.exe").first
  n.assemblies = asms
  n.options '/framework=net-4.0'
end

desc "Compile Solution, Run Tests"
task :default => [:release, :compile, :test]

task :nuspec_copy do
  conf_assert
  FileList[File.join('src', "*/bin", CONFIGURATION, "MassTransit.*.{dll,xml}")].keep_if{ |f|
    ff = f.downcase
    !(ff.include?("test") || ff.include?("msmq"))
  }.each { |f| 
    to = File.join( 'build/nuspec', 'lib', FRAMEWORK )
    FileUtils.mkdir_p to
    cp f, to
    File.join(FRAMEWORK, File.basename(f))
  }
end

directory 'build/nuspec'

desc "Create a nuspec for 'MassTransit.AzureServiceBus'"
nuspec :nuspec => ['build/nuspec', :nuspec_copy] do |nuspec|
  conf_assert
  nuspec.id = "MassTransit.AzureServiceBus"
  nuspec.version = NUGET_VERSION
  nuspec.authors = "Henrik Feldt, MPS Broadband"
  nuspec.owners = "Henrik Feldt"
  nuspec.description = "MassTransit transport library for Azure ServiceBus."
  nuspec.title = "MassTransit Azure ServiceBus Transport"
  nuspec.projectUrl = 'https://github.com/MassTransit/MassTransit-AzureServiceBus'
  nuspec.language = "en-GB"
  nuspec.licenseUrl = "http://www.apache.org/licenses/LICENSE-2.0"
  nuspec.requireLicenseAcceptance = "true"
  nuspec.dependency "MassTransit", "2.1.1"
  nuspec.dependency "WindowsAzure.ServiceBus", "1.7.0"
  nuspec.output_file = 'build/nuspec/MassTransit.AzureServiceBus.nuspec'
end

directory 'build/nuget'

desc "nuget pack 'MassTransit.AzureServiceBus'"
nugetpack :nuget => ['build/nuget', :nuspec] do |nuget|
  conf_assert
  nuget.command     = 'src/.nuget/NuGet.exe'
  nuget.nuspec      = 'build/nuspec/MassTransit.AzureServiceBus.nuspec'
  nuget.output      = 'build/nuget'
end

desc "publishes (pushes) the nuget package 'MassTransit.AzureServiceBus'"
nugetpush :nuget_push do |nuget|
  nuget.command = 'src/.nuget/NuGet.exe'
  nuget.package = File.join("build/nuget", 'MassTransit.AzureServiceBus' + "." + BUILD_VERSION + '.nupkg')
end

desc "publish nugets! (doesn't build)"
task :publish => [:everything, :nuget_push]

task :verify do
  changed_files = `git diff --cached --name-only`.split("\n") + `git diff --name-only`.split("\n")
  if !(changed_files == [".semver", "Rakefile.rb"] or 
    changed_files == ["Rakefile.rb"] or 
	changed_files == [".semver"] or
    changed_files.empty?)
    raise "Repository contains uncommitted changes; either commit or stash."
  end
end

task :git do 
  v = SemVer.find
  if `git tag`.split("\n").include?("#{v.to_s}")
    raise "Version #{v.to_s} has already been released! You cannot release it twice."
  end
  puts 'committing'
  `git commit -am "Released version #{v.to_s}"` 
  puts 'tagging'
  `git tag #{v.to_s}`
  puts 'pushing'
  `git push`
  `git push --tags`
end

desc "Perform a Full-on Release!"
task :everything => [:verify, :default, :git, :publish] do
  puts 'done'
end