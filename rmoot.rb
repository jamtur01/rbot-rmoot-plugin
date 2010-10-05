#-- vim:sw=2:et
##++
##
## :title: RMoot
##
## Author:: James Turnbull <james@lovedthanlost.net>
## Copyright:: (C) 2010 James Turnbull
## License:: GPLv3
##
#

class RmootPlugin < Plugin

        def initialize
          super
          @running = false
          @meetingname = nil
          @voting = false
          @votename = nil

          @topics  = Hash.new
          @voters = Hash.new
          @conclusion = Hash.new
        end

        def running?
          @running
        end

        def voting?
          @voting
        end

	def help(plugin, topic = "")
	  case topic
            when 'meeting':
              "Specify 'start' or 'stop' to start or stop a meeting."
            else
              "rMoot: A MootBot style IRC meeting manager. " +
              "Use 'start meeting meetingname' and 'stop meeting' to start or stop a meeting. " +
              "Use 'start vote votename' and 'stop vote' to start or stop voting. " +
              "Use +1 and -1 to vote for or against a topic." +
              "Use 'add item' where item can be action, idea, agreement, and link to add items. " +
              " "
          end
	end

        def start_meeting(m, params)

          @bot.auth.irc_to_botuser(m.source).set_temp_permission('rmoot::meeting', true, m.channel)

          case @running
            when false
              @running = true
              @meetingname = params[:meetingname].to_s
              m.reply "Starting meeting " + @meetingname
              return
            when true
              m.reply "There is already a meeting running!"
              return
          end
        end

        def stop_meeting(m, params)
          case @running
            when false
              m.reply "There is no meeting running!"
              return
            when true
              @running = false
              meeting_conclusion(m)
              return
          end
        end

        def listen(m)
          return if m.address?

          return unless voting?

          return unless m.message.index(/(\+|-)1/)

          if m.message =~ /(\+|-)1/
            vote = $1
            voter = m.sourcenick
            record_vote(m, vote, voter)
          end
        end

        def log_item(m, params)
          unless running?
             m.reply "A meeting must be started to specify an action."
             return
          end

          action = params[:action]
          type = params[:type]
          item = params[:item]

        end

        def manage_vote(m, params)
          unless running?
             m.reply "A meeting must be started to use voting."
             return
          end

          case @voting
            when false
              case params[:vote]
                when 'start', 'begin'
                  @voting = true
                  @votename = params[:votename].to_s
                  m.reply "A vote for " + @votename + " is now in progress. Specify +1 to vote aye and -1 to vote nay."
                  return
                when 'stop', 'end'
                  m.reply "There is no vote running."
                  return
              end
            when true
              case params[:vote]
                when 'start', 'begin'
                  m.reply "A vote is already in progress."
                  return
                when 'stop', 'end'
                  @voting = false
                  m.reply "The vote for " + @votename + " is now over."
                  voting_results(m)
                  return
              end
          end
        end

        def record_vote(m, vote, voter)
          if @voters.has_key? voter
            m.reply "You've already voted on " + @mvotename % { :vote => @voters[voter] }
            return
          end

          if vote == '+'
            choice = 'aye'
          elsif vote == '-'
            choice = 'nay'
          end

          @voters[voter] = choice

          m.reply "#{voter} voted " + choice + " on topic " + @votename
        end

        def voting_results(m)
          count = Hash.new(0)
          votes = @voters.values

          @voters.clear

          votes.each do |v| count[v] += 1 end

          aye = count['aye']
          nay = count['nay']

          m.reply "There were #{aye} votes for the affirmative and #{nay} votes for the negative."
          if aye > nay
            outcome = "The vote on " + @votename + " passed!"
          elsif aye < nay
            outcome = "The vote on " + @votename + " failed!"
          elsif aye == nay
            outcome = "The vote on " + @votename + " was a tie!"
          end

          @conclusion[@votename] = outcome
          m.reply "#{outcome}"

        end

        def log_items(m, params)
          unless running?
             m.reply "A meeting must be started to specify a " + params[:item]
             return
          end

          type = params[:type]
          item = params[:item].to_s

          if params[:action] == 'add' && !@conclusion.has_value?(item)
            @conclusion[type] = item
            m.reply "Adding #{type} - #{item}"
            return
          elsif params[:action] == 'add' && @conclusion.has_value?(item)
            m.reply "#{type} - #{item} already exists."
            return 
          elsif params[:action] == 'remove' && @conclusion.has_value?(item)
              @conclusion.delete_if { |k, v| v == item }
              m.reply "Removing #{type} - #{item} from meeting."
          else
              m.reply "No such #{type} - #{item} exists."
              return
          end
        end

        def meeting_conclusion(m)
          m.reply "Stopping " + @meetingname
          m.reply "The results of the meeting were: "
          @conclusion.each do |item, outcome|
            m.reply item + " - " + outcome
          end
        end
end

plugin = RmootPlugin.new

plugin.default_auth( 'meeting', false )

plugin.map 'rmoot start meeting *meetingname', :action => 'start_meeting'
plugin.map 'rmoot stop meeting', :action => 'stop_meeting', :auth_path => 'meeting'
plugin.map 'rmoot :action :type *item', :requirements => { :action => /(add|remove)/, :type => /(agreement|action|idea|link)/ }, :action => 'log_items'
plugin.map 'rmoot :vote vote *votename', :requirements => { :vote => /(start|begin|stop|end)/ }, :action => 'manage_vote', :auth_path => 'meeting'
