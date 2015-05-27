require './ci/common'

namespace :ci do
  namespace :windows do |flavor|
    task :before_install do |t|
      section('BEFORE_INSTALL')
      sh %(mkdir -p %VOLATILE_DIR%)
    end

    task :install do |t|
      section('INSTALL')
      sh %(python -m pip install --upgrade pip setuptools)
      sh %(pip install\
           -r requirements.txt\
           --cache-dir %PIP_CACHE%\
           2>&1 >> %VOLATILE_DIR%/ci.log)
      sh %(pip install\
           -r requirements-test.txt\
           --cache-dir %PIP_CACHE%\
            2>&1 >> %VOLATILE_DIR%/ci.log)
      t.reenable
    end

    task :before_script do |t|
      section('BEFORE_SCRIPT')
      sh %(cp ci/resources/datadog.conf.example datadog.conf)
      t.reenable
    end
    # If you need to wait on a start of a progran, please use Wait.for,
    # see https://github.com/DataDog/dd-agent/pull/1547

    task script: ['ci:common:script'] do
      sh %(nosetests --version)
      this_provides = [
        'windows'
      ]
      Rake::Task['ci:common:run_tests'].invoke(this_provides)
    end

    task before_cache: ['ci:common:before_cache']

    task cache: ['ci:common:cache']

    task cleanup: ['ci:common:cleanup']

    task :execute do
      exception = nil
      begin
        %w(before_install install before_script script).each do |t|
          Rake::Task["#{flavor.scope.path}:#{t}"].invoke
        end
      rescue => e
        exception = e
        puts "Failed task: #{e.class} #{e.message}".red
      end
      if ENV['SKIP_CLEANUP']
        puts 'Skipping cleanup, disposable environments are great'.yellow
      else
        puts 'Cleaning up'
        Rake::Task["#{flavor.scope.path}:cleanup"].invoke
      end
      fail exception if exception
    end
  end
end
