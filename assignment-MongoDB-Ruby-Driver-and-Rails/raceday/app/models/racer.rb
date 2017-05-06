require 'mongo'
require 'pp'

class Racer 
    include ActiveModel::Model
    attr_accessor :id, :number, :first_name, :last_name, :gender, :group, :secs
    
    def self.mongo_client
       Mongo::Client.new('mongodb://localhost:27017/raceday_development')
    end
  
    def self.collection
       self.mongo_client['racers']  
    end
    
    def persisted?
        !@id.nil?
    end
    
    def created_at
        nil
    end

    def updated_at
        nil
    end
  
    def initialize(params={})
        @id=params[:_id].nil? ? params[:id] : params[:_id].to_s
        @number=params[:number].to_i
        @first_name=params[:first_name]
        @last_name=params[:last_name]
        @gender=params[:gender]
        @group=params[:group]
        @secs=params[:secs].to_i
    end
  
    def self.all(prototype={}, sort={:number=>1}, skip=0, limit=nil)
        tmp = {} #hash needs to stay in stable order provided
        sort.each {|k,v| 
            tmp[k] = v  if [:number, :first_name, :last_name, :gender, :group, :secs].include?(k)
        }
        sort=tmp

        #convert to keys and then eliminate any properties not of interest
        #prototype=prototype.symbolize_keys.slice(:city, :state) if !prototype.nil?

        Rails.logger.debug {"getting all zips, prototype=#{prototype}, sort=#{sort}, skip=#{skip}, limit=#{limit}"}

        result=Racer.collection.find(prototype)
            .sort(sort)
            .skip(skip)
        result=result.limit(limit) if !limit.nil?

        return result 
    end
    
    def self.find id
        Rails.logger.debug {"getting zip #{id}"}
        objid = id.is_a?(String) ? BSON::ObjectId.from_string(id) : id
        result=collection.find(:_id=>objid).first
        return result.nil? ? nil : Racer.new(result)
    end
    
    def save
        result=self.class.collection.insert_one(_id:@id, number:@number, first_name:@first_name, last_name:@last_name, group:@group, gender:@gender, secs:@secs)
        @id=result.inserted_id.to_s #store just the string form of the _id
    end
    
    def update(params)
        Rails.logger.debug {"updating #{self}, id #{@id}, with #{params}"}
        @number=params[:number].to_i
        @first_name=params[:first_name]
        @last_name=params[:last_name]
        @gender=params[:gender]
        @group=params[:group]
        @secs=params[:secs].to_i
        params.slice!(:number, :first_name, :last_name, :gender, :group, :secs)
        Rails.logger.debug {"updating #{self} with #{params}"}
        self.class.collection.find(:_id=>BSON::ObjectId.from_string(@id)).update_one(params)
    end
    
    def destroy
       self.class.collection.find(:_id=>BSON::ObjectId.from_string(@id)).delete_one
    end

    
    
    def self.paginate(params)
       page=(params[:page] || 1).to_i
       limit=(params[:per_page] || 30).to_i
       skip=(page-1)*limit
       
       racers=[]
       all({},{}, skip, limit).each do |doc|
           racers << Racer.new(doc)
       end
       
       total=all({},{},0,1).count
       
       WillPaginate::Collection.create(page, limit, total) do |pager|
            pager.replace(racers)
        end
    end
end