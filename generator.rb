require 'bundler'

class Generator
  def initialize(pgdir)
    @pgdir = pgdir
  end

  def generate_nodetypes!
    inside = false
    @nodetypes = []

    lines = File.read(File.join(@pgdir, '/src/include/nodes/nodes.h'))
    lines.each_line do |line|
      if inside
        if line[/([A-z_]+)(\s+=\s+\d+)?,/]
          @nodetypes << $1[2..-1] # Without T_ prefix
        elsif line == "} NodeTag;\n"
          inside = false
        end
      elsif line == "typedef enum NodeTag\n"
        inside = true
      end
    end
  end

  INLINED_TYPES = [
    'Plan', 'Scan', 'Join',
    'Path', 'JoinPath',
    'CreateStmt',
  ]
  TYPE_OVERRIDES = {
    ['VacuumStmt', 'options']                => 'VacuumOption',
    ['Query', 'queryId']                     => :skip, # we intentionally do not print the queryId field
    ['RangeVar', 'catalogname']              => :skip, # presently not semantically meaningful
    ['PlannerGlobal', 'boundParams']         => :skip, # NB: this isn't a complete set of fields
    ['PlannerGlobal', 'subroots']            => :skip, # ^
    ['Plan', 'startup_cost']                 => ['float', '%.2f'],
    ['Plan', 'total_cost']                   => ['float', '%.2f'],
    ['Plan', 'plan_rows']                    => ['float', '%.0f'],
    ['IndexPath', 'indextotalcost']          => ['float', '%.2f'],
    ['IndexPath', 'indexselectivity']        => ['float', '%.4f'],
    ['BitmapAndPath', 'bitmapselectivity']   => ['float', '%.4f'],
    ['BitmapOrPath', 'bitmapselectivity']    => ['float', '%.4f'],
    ['MergeAppendPath', 'limit_tuples']      => ['float', '%.0f'],
    ['SubPlan', 'startup_cost']              => ['float', '%.2f'],
    ['SubPlan', 'per_call_cost']             => ['float', '%.2f'],
    ['ParamPathInfo', 'ppi_rows']            => ['float', '%.0f'],
    ['RestrictInfo', 'eval_cost']            => :skip, # NB: this isn't a complete set of fields
    ['RestrictInfo', 'scansel_cache']        => :skip, # ^
    ['RestrictInfo', 'left_bucketsize']      => :skip, # ^
    ['RestrictInfo', 'right_bucketsize']     => :skip, # ^
    ['RestrictInfo', 'parent_ec']            => :skip, # don't write, leads to infinite recursion in plan tree dump
    ['RestrictInfo', 'left_ec']              => :skip, # ^
    ['RestrictInfo', 'right_ec']             => :skip, # ^
    ['RestrictInfo', 'norm_selec']           => ['float', '%.4f'],
    ['RestrictInfo', 'outer_selec']          => ['float', '%.4f'],
    ['MinMaxAggInfo', 'subroot']             => :skip, # too large, not interesting enough
    ['MinMaxAggInfo', 'pathcost']            => ['float', '%.2f'],
    ['PlannerInfo', 'parent_root']           => :skip, # NB: this isn't a complete set of fields
    ['PlannerInfo', 'simple_rel_array_size'] => :skip, # ^
    ['PlannerInfo', 'join_rel_hash']         => :skip, # ^
    ['PlannerInfo', 'initial_rels']          => :skip, # ^
    ['PlannerInfo', 'planner_cxt']           => :skip, # ^
    ['PlannerInfo', 'non_recursive_plan']    => :skip, # ^
    ['PlannerInfo', 'join_search_private']   => :skip, # ^
    ['PlannerInfo', 'total_table_pages']     => ['float', '%.0f'],
    ['PlannerInfo', 'tuple_fraction']        => ['float', '%.4f'],
    ['PlannerInfo', 'limit_tuples']          => ['float', '%.0f'],
    ['RelOptInfo', 'rows']                   => ['float', '%.0f'],
    ['RelOptInfo', 'reltablespace']          => 'uint',
    ['RelOptInfo', 'pages']                  => 'uint',
    ['RelOptInfo', 'tuples']                 => ['float', '%.0f'],
    ['RelOptInfo', 'allvisfrac']             => ['float', '%.6f'],
    ['RelOptInfo', 'attr_needed']            => :skip, # NB: this isn't a complete set of fields
    ['RelOptInfo', 'attr_widths']            => :skip, # ^
    ['RelOptInfo', 'baserestrictcost']       => :skip, # ^
    ['RelOptInfo', 'fdwroutine']             => :skip, # don't try to print
    ['RelOptInfo', 'fdw_private']            => :skip, # ^
    ['IndexOptInfo', 'pages']                => 'uint',
    ['IndexOptInfo', 'tuples']               => ['float', '%.0f'],
    ['IndexOptInfo', 'reltablespace']        => :skip, # NB: this isn't a complete set of fields
    ['IndexOptInfo', 'amcostestimate']       => :skip, # ^
    ['IndexOptInfo', 'rel']                  => :skip, # Do NOT print rel field, else infinite recursion
    ['IndexOptInfo', 'indexkeys']            => :skip, # array fields aren't really worth the trouble to print
    ['IndexOptInfo', 'indexcollations']      => :skip, # ^
    ['IndexOptInfo', 'opfamily']             => :skip, # ^
    ['IndexOptInfo', 'opcintype']            => :skip, # ^
    ['IndexOptInfo', 'sortopfamily']         => :skip, # ^
    ['IndexOptInfo', 'reverse_sort']         => :skip, # ^
    ['IndexOptInfo', 'nulls_first']          => :skip, # ^
    ['IndexOptInfo', 'indexprs']             => :skip, # redundant since we print indextlist
    ['IndexOptInfo', 'canreturn']            => :skip, # we don't bother with fields copied from the pg_am entry
    ['IndexOptInfo', 'amcanorderbyop']       => :skip, # ^
    ['IndexOptInfo', 'amoptionalkey']        => :skip, # ^
    ['IndexOptInfo', 'amsearcharray']        => :skip, # ^
    ['IndexOptInfo', 'amsearchnulls']        => :skip, # ^
    ['IndexOptInfo', 'amhasgettuple']        => :skip, # ^
    ['IndexOptInfo', 'amhasgetbitmap']       => :skip, # ^
  }
  OUTNODE_NAME_OVERRIDES = {
    'VacuumStmt' => 'VACUUM',
    'InsertStmt' => 'INSERT INTO',
    'DeleteStmt' => 'DELETE FROM',
    'UpdateStmt' => 'UPDATE',
    'SelectStmt' => 'SELECT',
    'AlterTableStmt' => 'ALTER TABLE',
    'AlterTableCmd' => 'ALTER TABLE CMD',
    'CopyStmt' => 'COPY',
    'DropStmt' => 'DROP',
    'TruncateStmt' => 'TRUNCATE',
    'TransactionStmt' => 'TRANSACTION',
    'ExplainStmt' => 'EXPLAIN',
    'CreateTableAsStmt' => 'CREATE TABLE AS',
    'VariableSetStmt' => 'SET',
    'VariableShowStmt' => 'SHOW',
    'LockStmt' => 'LOCK',
    'CheckPointStmt' => 'CHECKPOINT',
    'CreateSchemaStmt' => 'CREATE SCHEMA',
    'DeclareCursorStmt' => 'DECLARECURSOR',
    'CollateExpr' => 'COLLATE',
    'CaseExpr' => 'CASE',
    'CaseWhen' => 'WHEN',
    'ArrayExpr' => 'ARRAY',
    'RowExpr' => 'ROW',
    'RowCompareExpr' => 'ROWCOMPARE',
    'CoalesceExpr' => 'COALESCE',
    'MinMaxExpr' => 'MINMAX',
  }
  def generate_outmethods!
    source = target = nil
    @outmethods = {}
    @inlined_outmethods = []

    lines = File.read(File.join(@pgdir, '/src/include/nodes/parsenodes.h')) +
            File.read(File.join(@pgdir, '/src/include/nodes/plannodes.h')) +
            File.read(File.join(@pgdir, '/src/include/nodes/primnodes.h')) +
            File.read(File.join(@pgdir, '/src/include/nodes/relation.h'))
    lines.each_line do |line|
      if source
        if line[/^\s+(struct |const )?([A-z0-9]+)\s+(\*)?([A-z_]+);/]
          name = $4
          orig_type = $2 + $3.to_s
          type, *args = TYPE_OVERRIDES[[source, name]] || orig_type
          if type == :skip || type == 'Expr'
            # Ignore
          elsif type == 'NodeTag'
            # Nothing
          elsif INLINED_TYPES.include?(type)
            # Inline this field as if its sub-fields were part of the struct
            @outmethods[target] += format("  _out%sInfo(str, (const %s *) node);\n\n", type, type)
          elsif type == 'Node*' || @nodetypes.include?(type[0..-2])
            @outmethods[target] += format("  WRITE_NODE_FIELD(%s);\n", name)
          elsif name == 'location' && type == 'int'
            @outmethods[target] += format("  WRITE_LOCATION_FIELD(%s);\n", name)
          elsif ['bool', 'long', 'Oid', 'char'].include?(type)
            @outmethods[target] += format("  WRITE_%s_FIELD(%s);\n", type.upcase, name)
          elsif ['int', 'int16', 'int32', 'AttrNumber'].include?(type)
            @outmethods[target] += format("  WRITE_INT_FIELD(%s);\n", name)
          elsif ['uint', 'uint16', 'uint32', 'Index', 'bits32'].include?(type)
            @outmethods[target] += format("  WRITE_UINT_FIELD(%s);\n", name)
          elsif type == 'char*'
            @outmethods[target] += format("  WRITE_STRING_FIELD(%s);\n", name)
          elsif type == 'float'
            @outmethods[target] += format("  WRITE_FLOAT_FIELD(%s, \"%s\");\n", name, args[0])
          elsif ['Bitmapset*', 'Relids'].include?(type)
            @outmethods[target] += format("  WRITE_BITMAPSET_FIELD(%s);\n", name)
          else # Enum
            @outmethods[target] += format("  WRITE_ENUM_FIELD(%s, %s);\n", name, type)
          end
        elsif line == format("} %s;\n", source)
          source = target = nil
        end
      elsif line[/typedef struct ([A-z]+)/]
        if INLINED_TYPES.include?($1)
          source = $1
          target = $1 + 'Info'
          @outmethods[target] = ''
          @outmethods[source] = format("  _out%s(str, (const %s *) node);\n\n", target, source)
        else
          source = target = $1
          @outmethods[source] = ''
        end
      elsif line[/^typedef ([A-z]+) ([A-z]+);/]
        @outmethods[$2] = @outmethods[$1]
      end
    end
  end

  IGNORE_LIST = [
    'A_Expr', # Complex case
    'A_Const', # Complex case
    'Constraint', # Complex case
    'RangeTblEntry', # Complex case
    'Expr', # Unclear why this isn't needed (FIXME)
    'Const', # Complex case
    'BoolExpr', # Complex case
    'Path', # Complex case
    'EquivalenceClass', # Complex case
    'MergeAppend', 'RecursiveUnion', 'MergeJoin', 'Sort', 'Group', 'Agg',
    'WindowAgg', 'Unique', 'SetOp' # Needs inline lists
    ]
  def generate!
    generate_nodetypes!
    generate_outmethods!

    defs = ''
    conds = ''

    INLINED_TYPES.each do |type|
      next if IGNORE_LIST.include?(type)
      defs += "static void\n"
      defs += format("_out%sInfo(StringInfo str, const %s *node)\n", type, type)
      defs += "{\n"
      defs += @outmethods[type + 'Info']
      defs += "}\n"
      defs += "\n"
    end

    @nodetypes.each do |type|
      next if IGNORE_LIST.include?(type)
      if outmethod = @outmethods[type]
        defs += "static void\n"
        defs += format("_out%s(StringInfo str, const %s *node)\n", type, type)
        defs += "{\n"
        defs += format("  WRITE_NODE_TYPE(\"%s\");\n", OUTNODE_NAME_OVERRIDES[type] || type.upcase)
        defs += "\n"
        defs += outmethod
        defs += "}\n"
        defs += "\n"

        conds += format("case T_%s:\n", type)
    		conds += format("  _out%s(str, obj);\n", type)
    		conds += "  break;\n"
      end
    end

    File.write(File.join(@pgdir, '/src/backend/nodes/outfuncs_shared_defs.c'), defs)
    File.write(File.join(@pgdir, '/src/backend/nodes/outfuncs_shared_conds.c'), conds)
  end
end

Generator.new('../postgresql-pg_query').generate!
