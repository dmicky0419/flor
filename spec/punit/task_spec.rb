
#
# specifying flor
#
# Thu Jun 16 21:20:42 JST 2016
#

require 'spec_helper'


describe 'Flor punit' do

  before :each do

    @unit = Flor::Unit.new('envs/test/etc/conf.json')
    @unit.conf['unit'] = 'u'
    @unit.hooker.add('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate
    @unit.start
  end

  after :each do

    @unit.shutdown if @unit
  end

  describe 'task' do

    it 'tasks' do

      r = @unit.launch(
        %q{
          task 'alpha'
        },
        wait: true)

      expect(r['point']).to eq('terminated')
      expect(r['payload']['ret']).to eq('alpha')
      expect(r['payload']['seen'].size).to eq(1)
      expect(r['payload']['seen'].first[0]).to eq('alpha')
      expect(r['payload']['seen'].first[1]).to eq(nil)
      expect(r['payload']['seen'].first[2]).to eq('AlphaTasker')
    end

    it 'can be cancelled' do

      r = @unit.launch(
        %q{
          sequence
            task 'hole'
        },
        payload: { 'song' => 'Marcia Baila' },
        wait: '0_0 task')

      expect(HoleTasker.message['exid']).to eq(r['exid'])

      r = @unit.queue(
        { 'point' => 'cancel', 'exid' => r['exid'], 'nid' => '0_0' },
        wait: true)

      expect(HoleTasker.message).to eq(nil)
      expect(r['point']).to eq('terminated')
      expect(r['payload'].keys).to eq(%w[ song holed ])
    end

    it "emits a point: 'return' message" do

      r = @unit.launch(
        %q{
          sequence
            task 'alpha'
        },
        wait: true)

      expect(r['point']).to eq('terminated')

      ret = @unit.journal.find { |m| m['point'] == 'return' }

      expect(ret['nid']).to eq('0_0')
      expect(ret['tasker']).to eq('alpha')
    end

    it "emits a point: 'return' message (backslash)" do

      r = @unit.launch(
        %q{
          sequence \ task 'alpha'
        },
        wait: true)

      expect(r['point']).to eq('terminated')

      ret = @unit.journal.find { |m| m['point'] == 'return' }

      expect(ret['nid']).to eq('0_0')
      expect(ret['tasker']).to eq('alpha')
    end

    it 'can reply with an error' do

      r = @unit.launch(
        %q{
          sequence \ task 'failfox'
        },
        wait: 'failed')

      sleep 0.7

      expect(r['nid']).to eq('0_0')
      expect(r['tasker']).to eq('failfox')
      expect(r['point']).to eq('failed')
      expect(r['pr']).to eq(2) # processing run is the second run

      expect(
        @unit.journal
          .each_with_index
          .collect { |m, i| "#{i}:#{m['point']}:#{m['from']}->#{m['nid']}" }
          .join("\n")
      ).to eq(%{
        0:execute:->0
        1:execute:0->0_0
        2:execute:0_0->0_0_0
        3:execute:0_0_0->0_0_0_0
        4:receive:0_0_0_0->0_0_0
        5:receive:0_0_0->0_0
        6:task:0_0->0_0
        7:end:->
        8:failed:0_0->0_0
        9:end:->
      }.ftrim)
    end

    it 'can reply with an error (BasicTasker#reply_with_error)' do

      r = @unit.launch(
        %q{
          sequence
            task 'failfox2'
        },
        wait: 'failed')

      sleep 0.7

      expect(r['point']).to eq('failed')
      expect(r['nid']).to eq('0_0')
      expect(r['tasker']).to eq('failfox2')
      expect(r['pr']).to eq(2) # processing run is the second run

      expect(
        @unit.journal
          .each_with_index
          .collect { |m, i| "#{i}:#{m['point']}:#{m['from']}->#{m['nid']}" }
          .join("\n")
      ).to eq(%{
        0:execute:->0
        1:execute:0->0_0
        2:execute:0_0->0_0_0
        3:execute:0_0_0->0_0_0_0
        4:receive:0_0_0_0->0_0_0
        5:receive:0_0_0->0_0
        6:task:0_0->0_0
        7:end:->
        8:failed:0_0->0_0
        9:end:->
      }.ftrim)
    end

    it 'passes information to the tasker' do

      r = @unit.launch(
        %q{
          india 'one'
          sequence tag: 'a'
            india 'two'
            sequence tags: [ 'b', 'c' ]
              india 'three' temperature: 'high'
        },
        wait: true)

      expect(r['point']).to eq('terminated')

      td = r['payload']['tasked'][0]

      expect(td['point']).to eq('task')
      expect(td['nid']).to eq('0_0')
      expect(td['taskname']).to eq('one')
      expect(td['attl']).to eq([ 'india', 'one' ])
      expect(td['attd']).to eq({})
      expect(td['er']).to eq(1) # execution run
      expect(td['m']).to eq(11)
      expect(td['pr']).to eq(1) # processing run
      expect(td['vars']).to eq(nil)
      expect(td['tags']).to eq([])
      expect(td['tconf']['require']).to eq('india.rb')
      expect(td['tconf']['class']).to eq('IndiaTasker')
      expect(td['tconf']['root']).to eq('envs/test/lib/taskers/india')
      expect(td['tconf']['_path']).to match(/\/lib\/taskers\/india\/dot\.json$/)

      td = r['payload']['tasked'][1]

      expect(td['point']).to eq('task')
      expect(td['nid']).to eq('0_1_1')
      expect(td['taskname']).to eq('two')
      expect(td['attl']).to eq([ 'india', 'two' ])
      expect(td['attd']).to eq({})
      expect(td['er']).to eq(2)
      expect(td['m']).to eq(32)
      expect(td['pr']).to eq(2)
      expect(td['vars']).to eq(nil)
      expect(td['tags']).to eq(%w[ a ])

      td = r['payload']['tasked'][2]

      expect(td['point']).to eq('task')
      expect(td['nid']).to eq('0_1_2_1')
      expect(td['taskname']).to eq('three')
      expect(td['attl']).to eq([ 'india', 'three' ])
      expect(td['attd']).to eq({ 'temperature' => 'high' })
      expect(td['er']).to eq(3)
      expect(td['m']).to eq(59)
      expect(td['pr']).to eq(3)
      expect(td['vars']).to eq(nil)
      expect(td['tags']).to eq(%w[ b c a ])
    end

    it 'lets the execution fails if the tasker is not found' do

      r = @unit.launch(
        %q{
          sequence
            task 'nemo'
        },
        wait: 'failed')

      sleep 0.7

      expect(r['point']).to eq('failed')
      expect(r['error']['msg']).to eq('tasker "nemo" not found')
      expect(r['nid']).to eq('0_0')
      expect(r['tasker']).to eq('nemo')
      expect(r['pr']).to eq(1) # processing run is the second run

      expect(
        @unit.journal
          .each_with_index
          .collect { |m, i| "#{i}:#{m['point']}:#{m['from']}->#{m['nid']}" }
          .join("\n")
      ).to eq(%{
        0:execute:->0
        1:execute:0->0_0
        2:execute:0_0->0_0_0
        3:execute:0_0_0->0_0_0_0
        4:receive:0_0_0_0->0_0_0
        5:receive:0_0_0->0_0
        6:failed:0_0->0_0
        7:end:->
      }.ftrim)
    end

    it 'lets the execution fails if the tasker is not found' do

      r = @unit.launch(
        %q{
          sequence
            nemo _
        },
        wait: 'failed')

      sleep 0.7

      expect(r['point']).to eq('failed')
      expect(r['error']['msg']).to eq("don't know how to apply \"nemo\"")

      # Nota Bene: not the same error message as when `task 'nemo'` !!!
    end

    #it 'does not alter the incoming f.ret' do
    #
    #  r = @unit.launch(
    #    %q{
    #      1234
    #      task 'alpha'
    #    },
    #    wait: true)
    #
    #  expect(r['point']).to eq('terminated')
    #  expect(r['payload']['ret']).to eq(1234)
    #end
      #
      # No. Let's leave it as is, last f.ret wins.

    context 'by:/for:/assign:/with:/task: attributes' do

        # task 'clean up' by: 'alan'
        # task 'clean up' for: 'alan'
        # task 'clean up' assign: 'alan'
        # task 'alan' with: 'clean up'
        # alan task: 'clean up'
          #
        # clean_up assign: 'alan'
        # "clean up" assign: 'alan'
          #
      they 'make assignation more readable' do

        r = @unit.launch(
          %q{
            task 'one' by: 'alpha'
            task 'two' for: 'alpha'
            task 'three' assign: 'alpha'
            task 'alpha' with: 'four'
            alpha task: 'five'
            task 'alpha'
            alpha 'six'
          },
          wait: true)

        expect(r['point']).to eq('terminated')

        expect(
          r['payload']['seen'].collect { |e| e[0, 2] }
        ).to eq([
          [ 'alpha', 'one' ],
          [ 'alpha', 'two' ],
          [ 'alpha', 'three' ],
          [ 'alpha', 'four' ],
          [ 'alpha', 'five' ],
          [ 'alpha', nil ],
          [ 'alpha', 'six' ],
        ])
      end

      they 'accept a tasker directly' do

        r = @unit.launch(
          %q{
            task 'one' by: alpha
            task 'two' for: alpha
            task 'three' assign: alpha
            task alpha with: 'four'
            alpha task: 'five'
            task alpha
          },
          wait: true)

        expect(r['point']).to eq('terminated')

        expect(
          r['payload']['seen'].collect { |e| e[0, 2] }
        ).to eq([
          [ 'alpha', 'one' ],
          [ 'alpha', 'two' ],
          [ 'alpha', 'three' ],
          [ 'alpha', 'four' ],
          [ 'alpha', 'five' ],
          [ 'alpha', nil ],
        ])
      end
    end
  end
end

