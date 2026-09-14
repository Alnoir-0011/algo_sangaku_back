class IntroduceDelegatedSangakuTypes < ActiveRecord::Migration[8.1]
  # sangakus / answers を delegated_type の共通テーブルへ転用し、出題形式ごとの
  # 子テーブルへ形式固有カラムを移す（issue #278）。
  #
  # 本番・開発とも Sangaku が 0 件であることを前提とした破壊的変更のため、データの
  # 移行は行わない。既存行が存在する場合は NOT NULL 列の追加時点で失敗し、
  # 意図せずデータを壊さないようにしてある。
  #
  # ECS では新しいタスクの起動に失敗すると circuit breaker が旧タスク定義へ戻すが、
  # スキーマは戻らない。部分適用を避けるため、一連の変更を 1 本にまとめている。
  def up
    create_table :code_sangakus do |t|
      t.text :description, null: false
      t.integer :difficulty, null: false, default: 0
      t.text :source, null: false
      t.timestamps
    end

    create_table :reorder_sangakus do |t|
      t.text :description, null: false
      t.integer :difficulty, null: false, default: 0
      t.timestamps
    end

    create_table :code_blocks do |t|
      t.references :reorder_sangaku, null: false, foreign_key: true
      t.text :content, null: false
      # null はダミーブロックを表す。PostgreSQL では NULL 同士は重複とみなされないため、
      # ダミーは 1 問あたり複数作れる。
      t.integer :correct_position
      t.timestamps
    end
    add_index :code_blocks, [ :reorder_sangaku_id, :correct_position ], unique: true

    create_table :code_answers do |t|
      t.text :source, null: false
      t.timestamps
    end

    create_table :reorder_answers do |t|
      t.integer :result, null: false
      t.timestamps
    end

    add_column :sangakus, :sangakuable_type, :string, null: false
    add_column :sangakus, :sangakuable_id, :bigint, null: false
    add_index :sangakus, [ :sangakuable_type, :sangakuable_id ], unique: true
    remove_column :sangakus, :description
    remove_column :sangakus, :source
    remove_column :sangakus, :difficulty

    add_column :answers, :answerable_type, :string, null: false
    add_column :answers, :answerable_id, :bigint, null: false
    add_index :answers, [ :answerable_type, :answerable_id ], unique: true
    remove_column :answers, :source

    # fixed_inputs は code_sangakus にぶら下げる
    remove_foreign_key :fixed_inputs, :sangakus
    remove_index :fixed_inputs, column: [ :content, :sangaku_id ]
    remove_index :fixed_inputs, column: :sangaku_id
    rename_column :fixed_inputs, :sangaku_id, :code_sangaku_id
    add_index :fixed_inputs, :code_sangaku_id
    add_index :fixed_inputs, [ :content, :code_sangaku_id ], unique: true
    add_foreign_key :fixed_inputs, :code_sangakus

    # answer_results は親 answers ではなく code_answers を参照させ、
    # 並べ替え解答に実行結果行がぶら下がる状態を構造的に作れなくする
    remove_foreign_key :answer_results, :answers
    remove_index :answer_results, column: [ :fixed_input_id, :answer_id ]
    remove_index :answer_results, column: :answer_id
    rename_column :answer_results, :answer_id, :code_answer_id
    add_index :answer_results, :code_answer_id
    add_index :answer_results, [ :fixed_input_id, :code_answer_id ], unique: true
    add_foreign_key :answer_results, :code_answers
  end

  def down
    remove_foreign_key :answer_results, :code_answers
    remove_index :answer_results, column: [ :fixed_input_id, :code_answer_id ]
    remove_index :answer_results, column: :code_answer_id
    rename_column :answer_results, :code_answer_id, :answer_id
    add_index :answer_results, :answer_id
    add_index :answer_results, [ :fixed_input_id, :answer_id ], unique: true
    add_foreign_key :answer_results, :answers

    remove_foreign_key :fixed_inputs, :code_sangakus
    remove_index :fixed_inputs, column: [ :content, :code_sangaku_id ]
    remove_index :fixed_inputs, column: :code_sangaku_id
    rename_column :fixed_inputs, :code_sangaku_id, :sangaku_id
    add_index :fixed_inputs, :sangaku_id
    add_index :fixed_inputs, [ :content, :sangaku_id ], unique: true
    add_foreign_key :fixed_inputs, :sangakus

    add_column :answers, :source, :text, null: false
    remove_index :answers, column: [ :answerable_type, :answerable_id ]
    remove_column :answers, :answerable_type
    remove_column :answers, :answerable_id

    add_column :sangakus, :description, :text, null: false
    add_column :sangakus, :source, :text, null: false
    add_column :sangakus, :difficulty, :integer, null: false, default: 0
    remove_index :sangakus, column: [ :sangakuable_type, :sangakuable_id ]
    remove_column :sangakus, :sangakuable_type
    remove_column :sangakus, :sangakuable_id

    drop_table :reorder_answers
    drop_table :code_answers
    drop_table :code_blocks
    drop_table :reorder_sangakus
    drop_table :code_sangakus
  end
end
