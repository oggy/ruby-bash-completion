#!/bin/sh

# Adapted from:
# Nicholas Seckar <nseckar@gmail.com>
# Saimon Moore <saimon@webtypes.com>
# http://www.webtypes.com/2006/03/31/rake-completion-script-that-handles-namespaces
# http://onrails.org/articles/2006/08/30/namespaces-and-rake-command-completion
# http://errtheblog.com/posts/31-rake-around-the-rosie

have rake &&
_rake()
{
    COMPREPLY=()
    local completions

    # we must pass COMP_LINE instead of COMP_WORDS[COMP_CWORD], since
    # bash treats "foo:bar" as two words
    completions=`ruby - "$COMP_LINE" <<'EOF'
      def main
        if have_rakefile?
          if have_cache?
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

      def have_rakefile?
        %w[Rakefile rakefile Rakefile.rb rakefile.rb].any?{|f| File.file?(f)}
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
        File.expand_path("~/.ruby-bash-completion/rake.#{Dir.pwd.hash}")
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

      main
EOF`
    COMPREPLY=( $completions )
    return 0
} &&
complete -F _rake rake
