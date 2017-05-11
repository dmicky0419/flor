
#
# specifying flor
#
# Thu May 11 12:01:58 JST 2017  圓さんの家
#

require 'spec_helper'


describe 'Flor procedures' do

  before :each do

    @executor = Flor::TransientExecutor.new
  end

  describe 'and' do

    it 'returns true if empty' do

      r = @executor.launch(
        %{
          and _
        })

      expect(r['point']).to eq('terminated')
      expect(r['payload']['ret']).to eq(true)
    end

    it 'returns true if all the children yield true' do

      r = @executor.launch(
        %{
          and true true
        })

      expect(r['point']).to eq('terminated')
      expect(r['payload']['ret']).to eq(true)
    end

    it 'returns false if a child yields false' do

      r = @executor.launch(
        %{
          and false true
        })

      expect(r['point']).to eq('terminated')
      expect(r['payload']['ret']).to eq(false)
    end
  end

  describe 'or' do

    it 'returns false if empty' do

      r = @executor.launch(
        %{
          or _
        })

      expect(r['point']).to eq('terminated')
      expect(r['payload']['ret']).to eq(false)
    end
  end

  describe 'and vs or' do

    it 'gives higher precedence to "and"'# do
#
#      r = @executor.launch(
#        %{
#          and true or false 2 FIXME
#        })
#
#      expect(r['point']).to eq('terminated')
#      expect(r['payload']['ret']).to eq(false)
#    end
  end
end

