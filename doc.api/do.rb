=begin

Before starting:

1. Set your environment variable `RUBYLIB` properly:
```
export RUBYLIB=~/code1/slave
```

2. Be sure you are working on the right branch and latest version:
```
cd ~/code1/slave
git fetch --all 
git reset --hard origin/2.0.0_Leandro
git switch 2.0.0_Leandro
git pull origin 2.0.0_Leandro

cd ~/code1/slave/extensions/mass.commons
git fetch --all 
git reset --hard origin/2.0.0_Leandro
git switch 2.0.0_Leandro
git pull origin 2.0.0_Leandro

cd ~/code1/slave/extensions/mass.slaves
git fetch --all 
git reset --hard origin/2.0.0_Leandro
git switch 2.0.0_Leandro
git pull origin 2.0.0_Leandro
```

3. Create a `config.rb` file in the same folder where this script is placed.
Write this code into `config.rb`

```ruby
OPENAI_API_KEY = '**************'
```
=end

require 'method_source'
require 'mysaas'
require 'lib/stubs'
require 'config'
DB = BlackStack.db_connect
require 'lib/skeletons'

# file with secrets - never push this file
require_relative './config.rb'

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

# GPT model to use
MODEL = 'gpt-4o'

# Instrusctions to initialize a GPT agent.
INSTRUCTIONS = "
Your name is Manolito and your work is to help me write the API documentation of our SaaS called MassProspecting.

This is the list of MassProspecting **classes** that you can operate via API:

- tag
- lead
- company
- profile

- lead_tag
- reminder

- headcount
- industry
- location
- revenue

- channel
- profile_type
- source_type
- enrichment_type
- outreach_type
- unsubscribe

- source
- job
- event

- outreach
- open
- link
- click

- request
- enrichment

- inboxcheck
- connectioncheck

- rule


If you are logged into your account of MassProspecting, you can try the **access points** in the following URLs:

`/ajax/:class/count.json`
`/ajax/:class/delete.json`
`/ajax/:class/get.json`
`/ajax/:class/insert.json`
`/ajax/:class/page.json`
`/ajax/:class/update.json`
`/ajax/:class/upsert.json`

Here is the source code if each one of the **access points** listed above:

**count.json:**
```erb
<%
return_message = {}
return_message['status'] = 'success'
begin
object = params[:object]
cls = BlackStack::API.classes[object.to_sym]
n = cls.where(:id_account => @account.id, :delete_time => nil).count
return_message['result'] = n
rescue Exception => e
return_message['status'] = @body['backtrace'] ? e.to_console : e.message
end
return return_message.to_json
%>
```

**delete.json:**
```erb
<%
return_message = {}
return_message['status'] = 'success'
begin
object = params[:object]
cls = BlackStack::API.classes[object.to_sym]
desc = @body
raise \"desc is required\" if desc.nil?
raise \"id is required\" if desc['id'].nil?
o = cls.where(:id=>desc['id'], :id_account=>@account.id).first
raise \"id not found\" if o.nil?
desc['id_account'] = @account.id
o.delete_time = now()
o.save
return_message['result'] = o.to_h
rescue Exception => e
return_message['status'] = @body['backtrace'] ? e.to_console : e.message
end
return return_message.to_json
%>
```

**get.json:**
```erb
<%
return_message = {}
return_message['status'] = 'success'
begin
object = params[:object]
cls = BlackStack::API.classes[object.to_sym]

id = @body['id']
raise \"id is required\" if id.nil?
raise \"id is not a guid\" if id && !id.guid?

o = cls.where(:id_account => @account.id, :id => id, :delete_time => nil).first

raise \"\#{object.to_s} not found\" if o.nil?
return_message['result'] = o.to_h
rescue Exception => e
return_message['status'] = @body['backtrace'] ? e.to_console : e.message
end
return return_message.to_json
%>
```

**insert.json:**
```erb
<%
return_message = {}
return_message['status'] = 'success'
begin
object = params[:object]
cls = BlackStack::API.classes[object.to_sym]
desc = @body
raise \"desc is required\" if desc.nil?
desc['id_account'] = @account.id
return_message['result'] = cls.insert(desc).to_h
rescue Exception => e
return_message['status'] = @body['backtrace'] ? e.to_console : e.message
end
return return_message.to_json
%>
```

**page.json:**
```erb
<%
return_message = {}
return_message['status'] = 'success'
begin
object = params[:object]
cls = BlackStack::API.classes[object.to_sym]
page = (@body['page'] || 1).to_i
limit = (@body['limit'] || 25).to_i
filters = @body['filters'] || {}
order = @body['order'] || 'id'
asc = @body['asc'].nil? ? true : @body['asc']
#binding.pry
# getting the dataset
ds = cls.page(@account, page: page, limit: limit, filters: filters)
return_message['count'] = cls.count(@account, filters: filters)
ds = asc ? ds.order(order.to_sym) : ds.order(Sequel.desc(order.to_sym))
ds = ds.limit(limit).offset((page-1)*limit)

#n = ds.count
arr = ds.all

#return_message['total'] = n
return_message['results'] = arr.map { |o| o.to_h }
rescue Exception => e
return_message['status'] = @body['backtrace'] ? e.to_console : e.message
end
return return_message.to_json
%>
```

**update.json:**
```erb
<%
return_message = {}
return_message['status'] = 'success'
begin
object = params[:object]
cls = BlackStack::API.classes[object.to_sym]
desc = @body
raise \"desc is required\" if desc.nil?
raise \"id is required\" if desc['id'].nil?
o = cls.where(:id=>desc['id'], :id_account=>@account.id).first
raise \"id not found\" if o.nil?
desc['id_account'] = @account.id
return_message['result'] = o.update(desc).to_h
rescue Exception => e
return_message['status'] = @body['backtrace'] ? e.to_console : e.message
end
return return_message.to_json
%>
```

**upsert.json:**
```erb
<%
return_message = {}
return_message['status'] = 'success'
begin
object = params[:object]
cls = BlackStack::API.classes[object.to_sym]
desc = @body
raise \"desc is required\" if desc.nil?
desc['id_account'] = @account.id
return_message['result'] = cls.upsert(desc).to_h
rescue Exception => e
return_message['status'] = @body['backtrace'] ? e.to_console : e.message
end
return return_message.to_json
%>
```

Also, here is a Ruby code with modules utilized by the classes.
For your convenience, here is the list of modules:
```
BlackStack::InsertUpdate
BlackStack::Serialize
BlackStack::Palette
BlackStack::Storage
BlackStack::Status
BlackStack::DomainProtocol
BlackStack::Validation
BlackStack::Tristate
BlackStack::Constants
BlackStack::State
BlackStack::VerificationResult
BlackStack::Access
BlackStack::Direction
BlackStack::MTA
BlackStack::Body
BlackStack::Type
BlackStack::Triggerable
BlackStack::Parameters
BlackStack::Filterable
BlackStack::Actionable
BlackStack::Unit
BlackStack::Skip
BlackStack::TimelinePendings
```

FURTHER WORK:

I will provide the source code of each one of the classes, and I'll need you to write a markdown document of such an class.

I will provide the source code of the modules included or extended by such a class.

Each document must have the following stucture:
d
1. Insert: 
  Required fields,
  optional fields, 
  validations, 
  list of allowed values, 
  examples. 
  Refer to the source code of `ajax/:class/insert.json` and the source code of the class that I will provide.
2. Page: 
  Required fields, 
  optional fields, 
  validations, 
  list of allowed values, 
  examples. 
  Refer to the source code of `ajax/:class/page.json` and the source code of the class that I will provide.
  Don't forget to include parameters `order` and `asc` into the call to `page.json`.
3. Update: 
  Required fields, 
  optional fields, 
  validations, 
  list of allowed values, 
  example.

First title must be header-1.
Each title listed above must be header-2.

Never include the `id_account` key in the requests, such key is added by the access point listeners.

Always provide a downloadable markdown file.

Please check carefully the list of allowed values before you write them.
Please check carefully the list of validations before you write them.
Please check carefully the list of fields before you write them.


When I provide the source code of the class to write documentation, reivew the source code of all the modules listed in the class definition before start writing documentation.

Please check carefully the list of allowed values before you write them.
Please check carefully the list of validations before you write them.
Please check carefully the list of fields before you write them.


"

# List of allowed channels.
# TODO: Bring this from database.
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

# List of allowed profile_types.
# TODO: Bring this from database.
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

# List of allowed outreach_types.
# TODO: Bring this from database.
OUTREACH_TYPES = [
  "Facebook_DirectMessage",
  "Facebook_FriendRequest",
  "GMail_DirectMessage",
  "LinkedIn_ConnectionRequest",
  "LinkedIn_DirectMessage",
  "Postmark_DirectMessage",
]

# List of allowed enrichment_types.
# TODO: Bring this from database.
ENRICHMENT_TYPES = [
  "ApolloRPA_CompanyDomainToLeads",
  "ApolloRPA_NameAndLinkedInUrlToEmail",
  "FindyMailAPI_NameAndDomainToEmail",
  "Reoon_EmailVerification",
  "ZeroBounce_EmailVerification",
]

# Classes to write API documentation
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

# Initialize the conversation with the system prompt
@messages = []
@messages << { 
  role: 'user', 
  content: INSTRUCTIONS 
}

# OpenAI client
@gpt = OpenAI::Client.new(access_token: OPENAI_API_KEY)


# helper function
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

# helper function
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

# helper function
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

# helper function
# get response from GPT
def response(s)
  @messages << { 
    role: 'user', 
    content: s, # prompt 
  }
  
  response = @gpt.chat(
    parameters: {
      model: MODEL,
      messages: @messages,
      #functions: functions,
      #function_call: "auto",  # Let the assistant decide when to call a function
    }
  )
  
  message = response['choices'][0]['message']['content']
  @messages << message
  
  message
end  

#response = @gpt.models.list
#models = response['data'].map { |model| model['id'] }
#puts models
#exit(0)

classes.each_with_index { |cls, i|
  filename = "#{(i+2).to_s.rjust(2,'0')}-#{cls.name.split('::').last.downcase}.md"
  print "#{filename}... "
  # generate prompt
  s = prompt(cls, filename)
  # get the response
  r = response(s)
  # Expand the home directory and construct the full path
  file_path = File.expand_path("~/Downloads/#{filename}")
  # Create or overwrite the file with the content of `s`
  File.open(file_path, "w") do |file|
    file.write(r)
  end
  puts 'done'.green
break
}

