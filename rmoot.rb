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
          @mtopic = nil
          @voting = false

          @topics  = Hash.new
          @voters = Hash.new

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
            when 'topic':
              "When a meeting is started specify a meeting topic."
            else
              "rMoot: A MootBot style IRC meeting manager. " +
              "Use 'start meeting' or 'stop meeting' to start or stop a meeting. " +
              "In a meeting, use 'topic topicofmeeting' to set the meeting topic.  " +
              "Use 'start' vote or 'stop vote' to start or stop voting. " +
              " "
          end
	end

        def meeting(m, params)

          case @running
            when false
              case params[:meeting]
                when 'start'
                  @running = true
                  m.reply "Starting meeting"
                  return
                when 'stop'
                  m.reply "No meeting running"
                  return
              end
             when true
               case params[:meeting]
                 when 'stop'
                   @running = false
                   m.reply "Stopping the meeting"
                   meeting_conclusion(m)
                   return
                 when 'start'
                   m.reply "There is already a meeting running"
                   return
               end
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

        def set_topic(m, params)
          unless running?
             m.reply "A meeting must be started to specify a topic."
             return
          end

          @mtopic = params[:mtopic].to_s

          if @mtopic
             m.reply "The current topic is: " + @mtopic
          else
             m.reply "You need to specify a topic."
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

        def vote(m, params)
          unless running?
             m.reply "A meeting must be started to use voting."
             return
          end

          unless @mtopic
             m.reply "You must have a topic to use voting."
             return
          end

          case @voting
            when false
              case params[:vote]
                when 'start'
                  @voting = true
                  m.reply "A vote for " + @mtopic.to_s + " is now in progress."
                  return
                when 'stop'
                  m.reply "There is no vote running."
                  return
              end
            when true
              case params[:vote]
                when 'start'
                  m.reply "A vote is already in progress."
                  return
                when 'stop'
                  @voting = false
                  m.reply "The vote for " + @mtopic.to_s + " is now over."
                  voting_results(m)
                  return
              end
          end
        end

        def record_vote(m, vote, voter)
          if @voters.has_key? voter
            m.reply "You've already voted on " + @mtopic.to_s % { :vote => @voters[voter] }
            return
          end

          if vote == '+'
            choice = 'aye'
          elsif vote == '-'
            choice = 'nay'
          end

          @voters[voter] = choice

          m.reply "#{voter} voted " + choice + " on topic " + @mtopic.to_s
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
            m.reply "The vote on " + @mtopic.to_s + " passed!"
            return
          elsif aye < nay
            m.reply "The vote on " + @mtopic.to_s + " failed!"
            return
          elsif aye == nay
            m.reply "The vote on " + @mtopic.to_s + " was a tie!"
            return
          end

        end

        def meeting_conclusion(m)

        end
end

plugin = RmootPlugin.new
plugin.map 'rmoot :meeting meeting', :requirements => { :meeting => /(start|stop)/ }, :action => 'meeting'
plugin.map 'rmoot topic *mtopic', :action => 'set_topic'
plugin.map 'rmoot :action :type *item', :requirements => { :act => /(add|remove)/, :type => /(action|agreement|idea|link)/ }, :action => 'log_items'
plugin.map 'rmoot :vote vote', :requirements => { :vote => /(start|stop)/ }, :action => 'vote'
