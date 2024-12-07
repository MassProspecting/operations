=begin
export RUBYLIB=~/code1/slave
=end

require 'method_source'

require 'mysaas'
require 'lib/stubs'
require 'config'
DB = BlackStack.db_connect
require 'lib/skeletons'

print 'Loading extensions configuration... '
# include the libraries of the extensions
# reference: https://github.com/leandrosardi/mysaas/issues/33
BlackStack::Extensions.extensions.each { |e|
  require "extensions/#{e.name.downcase}/main"
}
puts 'done'.green

print 'Loading extensions models... '
# Load skeleton classes
BlackStack::Extensions.extensions.each { |e|
  require "extensions/#{e.name.downcase}/lib/skeletons"
}
puts 'done'.green

classes = [
    Mass::Tag
]

def get_method_source(method_object)
    file, line = method_object.source_location
    return "Source not available" unless file && File.exist?(file)
  
    lines = File.readlines(file)
    method_lines = []
    current_line = line - 1
    indentation = nil
    method_started = false
  
    while current_line < lines.size
      line_content = lines[current_line]
      
      # Detect method definition
      if line_content =~ /^\s*(def|class|module)\s/
        method_started = true
        indentation = line_content[/^\s*/]
      end
  
      if method_started
        method_lines << line_content
        # Detect end of method
        if line_content =~ /^\s*end\b/ && line_content.start_with?(indentation)
          break
        end
      end
  
      current_line += 1
    end
  
    method_lines.join
end
  

#BlackStack::Serialize
#mod = BlackStack::Serialize

def get_module_code(mod)
    # Retrieve all singleton method names defined directly in BlackStack::Serialize
    singleton_method_names = mod.singleton_methods(false)

    # Map method names to Method objects
    singleton_methods = singleton_method_names.map do |method_name|
        mod.method(method_name)
    end

    # Retrieve all instance method names defined directly in BlackStack::Serialize
    instance_method_names = mod.instance_methods(false)

    # Map method names to UnboundMethod objects
    instance_methods = instance_method_names.map do |method_name|
        mod.instance_method(method_name)
    end

    methods = singleton_methods + instance_methods

    methods.map { |met|
        #puts met.to_s
        get_method_source(met)
    }
end # def get_module_code

# -----

CHANNELS = [
  "Apollo",
  "Facebook",
  "FindyMail",
  "GMail",
  "Indeed",
  "LinkedIn",
  "Postmark",
  "Reoon",
  "Targetron",
  "ZeroBounce",
]

PROFILE_TYPES = [
  "Apollo_API",
  "Apollo_RPA",
  "Facebook",
  "FindyMail",
  "GMail",
  "Indeed",
  "LinkedIn",
  "Postmark",
  "Reoon",
  "Targetron_API",
  "Targetron_RPA",
  "ZeroBounce",
]

OUTREACH_TYPES = [
  "Facebook_DirectMessage",
  "Facebook_FriendRequest",
  "GMail_DirectMessage",
  "LinkedIn_ConnectionRequest",
  "LinkedIn_DirectMessage",
  "Postmark_DirectMessage",
]

ENRICHMENT_TYPES = [
  "ApolloRPA_CompanyDomainToLeads",
  "ApolloRPA_NameAndLinkedInUrlToEmail",
  "FindyMailAPI_NameAndDomainToEmail",
  "Reoon_EmailVerification",
  "ZeroBounce_EmailVerification",
]

# -----

def prompt(cls, filename)
    imods = cls.included_modules.select! { |mod| mod.name =~ /Mass::/ || mod.name =~ /BlackStack::/ }
    emods = cls.singleton_class.included_modules.select! { |mod| mod.name =~ /Mass::/ || mod.name =~ /BlackStack::/ }

    s = "The name of the file must be `#{filename}`

The class is #{cls.name}, and its source code is below.
**#{cls.name}:**
```ruby
#{get_module_code(cls).join("\n")}
```

Also, the class #{cls.name} indludes #{imods.size} modules:
#{imods.map { |mod| "- #{mod.name}" }.join("\n") }

Also, the class #{cls.name} extends #{emods.size} modules:
#{emods.map { |mod| "- #{mod.name}" }.join("\n") }

Below is the source code of each one of the modules:

"

s += imods.map { |mod|
"
**Included module: #{mod.name}:**
```ruby
#{get_module_code(mod).join("\n")}
```
"
}.join("\n")

s += emods.map { |mod|
"
**Extended module: #{mod.name}:**
```ruby
#{get_module_code(mod).join("\n")}
```
"}.join("\n")

s += "

The allowed values of channels are: #{CHANNELS.join('", "')}.
The allowed values of profile_types are: #{PROFILE_TYPES.join('", "')}.
The allowed values of outreach_types are: #{OUTREACH_TYPES.join('", "')}.
The allowed values of enrichment_types are: #{ENRICHMENT_TYPES.join('", "')}.
"

    s
end

classes = [
  Mass::Tag,
  Mass::Lead,
  Mass::Company,
  Mass::Profile,

  Mass::LeadTag,
  Mass::Reminder,

  Mass::Headcount,
  Mass::Industry,
  Mass::Location,
  Mass::Revenue,

  Mass::Channel,
  Mass::ProfileType,
  Mass::SourceType,
  Mass::EnrichmentType,
  Mass::OutreachType,

  Mass::Source,
  Mass::Job,
  Mass::Event,

  Mass::Outreach,
  Mass::Open,
  Mass::Link,
  Mass::Click,
  Mass::Unsubscribe,

  Mass::Request,

  Mass::Enrichment,

  Mass::InboxCheck,
  Mass::ConnectionCheck,

  Mass::Rule,
]

classes.each_with_index { |cls, i|
  filename = "#{(i+1)}-#{cls.name.split('::').last.downcase}.md"
  print "#{filename}... "
  # generate prompt
  s = prompt(cls, filename)
  # Expand the home directory and construct the full path
  file_path = File.expand_path("~/Downloads/#{filename}.txt")
  # Create or overwrite the file with the content of `s`
  File.open(file_path, "w") do |file|
    file.write(s)
  end
  puts 'done'.green
}

