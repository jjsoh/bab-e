class Babe < ActiveRecord::Migration[5.0]
  def change
    create_table :users do |t|
          t.string :fname
          t.string :lname
          t.string :bname
          t.integer :gender
          t.string :password
      end
      
       create_table :breasts do |t|
          t.string :side
          t.integer :quality
          t.datetime :start
          t.datetime :end
      end
      
      create_table :bottles do |t|
          t.float :amount
          t.datetime :start
          t.datetime :end
      end
      
      create_table :pumpings do |t|
          t.string :side
          t.integer :quality
          t.float :amount
          t.datetime :start
          t.datetime :end
      end
      
      create_table :diapers do |t|
          t.integer :dtype
          t.datetime :start
          t.datetime :end

      end
      
  end
end
