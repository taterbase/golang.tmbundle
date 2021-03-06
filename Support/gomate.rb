#!/usr/bin/env ruby -wKU

require ENV['TM_SUPPORT_PATH'] + '/lib/exit_codes'
require ENV['TM_SUPPORT_PATH'] + '/lib/textmate'
require ENV['TM_SUPPORT_PATH'] + '/lib/tm/executor'
require ENV['TM_SUPPORT_PATH'] + '/lib/tm/process'
require ENV['TM_SUPPORT_PATH'] + '/lib/tm/save_current_document'

# TextMate's special GOPATH used in .tm_properties files prepended to the environment's GOPATH
ENV['GOPATH'] = (ENV.has_key?('TM_GOPATH') ? ENV['TM_GOPATH'] : '') +
                (ENV.has_key?('GOPATH') ? ':' + ENV['GOPATH'] : '').sub(/^:+/,'')

# Call tool to determine gopath
if ENV.has_key?('TM_GO_DYNAMIC_GOPATH')
  Dir.chdir(ENV['TM_DIRECTORY']) do
    ENV['GOPATH'] = `#{ENV['TM_GO_DYNAMIC_GOPATH']}`.chomp
  end
end

module Go
  def Go::go(command, options={})
    # TextMate's special TM_GO or expect 'go' on PATH
    go_cmd = ENV['TM_GO'] || 'go'

    TextMate.save_if_untitled('go')
    TextMate::Executor.make_project_master_current_document

    args = options[:args] ? options[:args] : []
    opts = {:use_hashbang => false, :version_args => ['version'], :version_regex => /\Ago version (.*)/}
    opts[:verb] = options[:verb] if options[:verb]

    # Default to running against directory, which in go should be the package.
    # Doesn't hold for "go run", which needs to be executed against the file.
    # The same will happend if directory is not set.
    directory = ENV['TM_DIRECTORY']
    if directory
      opts[:chdir] = directory
    end

    # Call tool to determine package; default to directory name
    pkg = directory
    if ENV.has_key?('TM_GO_DYNAMIC_PKG')
      Dir.chdir(ENV['TM_DIRECTORY']) do
        pkg = `#{ENV['TM_GO_DYNAMIC_PKG']}`.chomp
        pkg = nil if pkg == nil || pkg.empty?
      end
    end

    if command == 'run' || !pkg
      args.push(ENV['TM_FILEPATH'])
    else
      args.push("-v") # list packages being operated on
      opts[:noun] = pkg
    end
    args.push(opts)

    TextMate::Executor.run(go_cmd, command, *args)
  end
  
  def Go::gogetdoc
    # TextMate's special TM_GOGETDOC or expect 'gogetdoc' on PATH
    gogetdoc_cmd = ENV['TM_GOGETDOC'] || 'gogetdoc'
    
    # Save file. gogetdoc only accepts guru's archive format, which we don't currently support
    TextMate.save_if_untitled('go')
    
    # load current document from stdin
    document = []
    while line = $stdin.gets
      document.push(line)
    end

    # byte offset of cursor position from the beginning of file
    cursor = document[ 0, ENV['TM_LINE_NUMBER'].to_i - 1].join().length + ENV['TM_LINE_INDEX'].to_i

    args = []
    args.push(gogetdoc_cmd)
    args.push('-pos')
    args.push("#{ENV['TM_FILEPATH']}:##{cursor}")

    out, err = TextMate::Process.run(*args)

    if err.nil? || err == ''
      if out.length < 400
        TextMate.exit_show_tool_tip(out)
      else
        TextMate.exit_create_new_document(out)
      end
    else
      TextMate.exit_show_tool_tip(err)
    end

  end

  def Go::godef
    # TextMate's special TM_GODEF or expect 'godef' on PATH
    godef_cmd = ENV['TM_GODEF'] || 'godef'

    TextMate.save_if_untitled('go')

    # load current document from stdin
    document = []
    while line = $stdin.gets
      document.push(line)
    end

    # byte offset of cursor position from the beginning of file
    cursor = document[ 0, ENV['TM_LINE_NUMBER'].to_i - 1].join().length + ENV['TM_LINE_INDEX'].to_i

    args = []
    args.push(godef_cmd)
    args.push('-f')
    args.push(ENV['TM_FILEPATH'])
    args.push('-o')
    args.push("#{cursor}")

    # /usr/local/Cellar/go/1.7.1/libexec/src/database/sql/sql.go:960:15
    out, err = TextMate::Process.run(*args)

    if err.nil? || err == ''
      file_details = out.split(':')
      TextMate.go_to(:file => file_details[0],
                     :line => file_details[1],
                     :column => file_details[2].to_i)
    else
      TextMate.exit_show_tool_tip(err)
    end
  end

  def Go::golint
    golint = ENV['TM_GOLINT'] || 'golint'
    TextMate.save_if_untitled('go')
    TextMate::Executor.make_project_master_current_document

    args = Array.new
    opts = {:use_hashbang => false, :verb => 'Linting', :version_replace => 'golint'}

    file_length = ENV['TM_DIRECTORY'].length + 1
    go_file = ENV['TM_FILEPATH'][file_length..-1]
    opts[:chdir] = ENV['TM_DIRECTORY']

    args.push(go_file)
    args.push(opts)

    TextMate::Executor.run(golint, *args)
  end
end
