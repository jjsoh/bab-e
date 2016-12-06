class Babe < ActiveRecord::Migration[5.0]
  def change
    create_table :user do |t|
          t.string :fname
          t.string :lname
          t.string :bname
          t.integer :gender
          t.string :password
      end
      
       create_table :breast do |t|
          t.integer :side
          t.integer :quality
          t.datetime :start
          t.datetime :end
      end
      
      create_table :bottle do |t|
          t.float :amount
          t.datetime :start
          t.datetime :end

      end
      
      create_table :pumping do |t|
          t.integer :side
          t.integer :quality
          t.float :amount
          t.datetime :start
          t.datetime :end
      end
      
      create_table :diaper do |t|
          t.integer :type
          t.integer :quality
          t.datetime :start
          t.datetime :end

      end
      
  end
end
