#!/bin/sh

#
# Completion for rake and cap.
#

# Adapted from:
# Nicholas Seckar <nseckar@gmail.com>
# Saimon Moore <saimon@webtypes.com>
# http://www.webtypes.com/2006/03/31/rake-completion-script-that-handles-namespaces
# http://errtheblog.com/posts/31-rake-around-the-rosie
# http://onrails.org/articles/2006/11/17/rake-command-completion-using-rake
# http://www.brynary.com/2007/5/3/tab-completion-for-capistrano-tasks-in-bash

_rake_base_code()
{
    base_code=`cat <<'EOF'
      class Completer
        def initialize(command)
          @command = command
        end

        def run
          if have_taskfile?
            if have_cache? && no_dependencies_modified?
              complete cache, stem
              background{update_cache}
            else
              update_cache
              complete cache, stem
            end
          else
            complete options, stem
          end
        end

        def have_taskfile?
          Dir[*taskfiles].all?{|path| File.file?(path)}
        end

        def no_dependencies_modified?
          Dir[*(taskfiles + extra_dependencies)].all? do |path|
            File.mtime(path) < File.mtime(cache_file)
          end
        end

        def extra_dependencies
          []
        end

        def have_cache?
          File.file? cache_file
        end

        def stem
          ARGV.first[/\S*\z/]
        end

        def complete(completions, stem)
          # strip stuff bash would consider part of the previous word
          completions = completions.grep(/\A#{Regexp.escape stem}/)
          prefix = stem[/\A.*:/] and
            completions = completions.map{|t| t.sub(/\A#{Regexp.escape prefix}/, '')}
          puts completions
        end

        def cache_file
          File.expand_path("~/.ruby-bash-completion/#{@command}.#{Dir.pwd.hash}")
        end

        def cache
          @cache ||= File.read(cache_file)
        end

        def background(&block)
          child_pid = fork do
            STDOUT.reopen('/dev/null')  # don't keep bash waiting on us
            yield
          end
          Process.detach(child_pid)
        end

        def update_cache
          @cache = options + tasks
          require 'fileutils'
          FileUtils.mkdir_p(File.dirname(cache_file))
          open(cache_file, 'w'){|f| f.puts @cache}
        end
      end
EOF`
}

have rake &&
_rake()
{
    COMPREPLY=()
    local completions base_code command_code

    _rake_base_code
    command_code=`cat <<'EOF'
      class RakeCompleter < Completer
        def taskfiles
          %w[Rakefile rakefile Rakefile.rb rakefile.rb]
        end

        def extra_dependencies
          ['lib/tasks/**/*.rake', 'vendor/plugins/*/tasks/**/*.rake']
        end

        def options
          %w[
            --classic-namespace  -C
            --describe           -D
            --dry-run            -n
            --help               -h
            --libdir             -I
            --nosearch           -N
            --prereqs            -P
            --quiet              -q
            --rakefile           -f
            --rakelibdir         -R
            --require            -r
            --silent             -s
            --tasks              -T
            --trace              -t
            --verbose            -v
            --version            -V
          ]
        end

        def tasks
          \`rake --silent --tasks\`.split("\n").collect {|line| line.split[1]}
        end
      end
      RakeCompleter.new('rake').run
EOF`

    # we must pass COMP_LINE instead of COMP_WORDS[COMP_CWORD], since
    # bash treats "foo:bar" as two words
    completions=`ruby - "$COMP_LINE" <<EOF
      $base_code
      $command_code
EOF`
    COMPREPLY=( $completions )
    return 0
} &&
complete -F _rake rake

have cap &&
_cap()
{
    COMPREPLY=()
    local completions base_code command_code

    _rake_base_code
    command_code=`cat <<'EOF'
      class CapCompleter < Completer
        def taskfiles
          %w[Capfile config/deploy.rb]
        end

        def options
          %w[
            -e, --explain
            -F, --default-config
            -f, --file
            -H, --long-help
            -h, --help
            -p, --password
            -q, --quiet
            -S, --set-before
            -s, --set
            -T, --tasks
            -V, --version
            -v, --verbose
            -X, --skip-system-config
            -x, --skip-user-config
          ]
        end

        def tasks
          \`cap -T|grep "^cap"|cut -d " " -f 2\`.split
        end
      end
      CapCompleter.new('cap').run
EOF`

    # we must pass COMP_LINE instead of COMP_WORDS[COMP_CWORD], since
    # bash treats "foo:bar" as two words
    completions=`ruby - "$COMP_LINE" <<EOF
      $base_code
      $command_code
EOF`
    COMPREPLY=( $completions )
    return 0
} &&
complete -F _cap cap
