# log_manager
A Logger that carries data/variables constantly used on log messages.

## Other features:
- Cut long logs
- Notifies NewRelic on error log
  Specially usefull when errors are detected out of the web request, like ActiveJobs or Rabbitmq Messages
- Log progress of long and iterational processes


This class uses method_missing to create dinamic logging messages.
If the method finishes with `_start`, `_finish`, or `_iteration`,
the correspondent log messages will be created.
Usage example:
```
  def prepare_data_structure_to_insert
    @log_manager.prepare_data_structure_to_insert_start
    associate_catalogo_and_sku_via_dna_crc do |dna_crc|
      hash = @records_by_dna_crc[dna_crc]
      hash[:covers].concat(hash[:rec].catalogo_dna.booktree_capas)

      @log_manager.prepare_data_structure_to_insert_iteration
    end
    @log_manager.prepare_data_structure_to_insert_finish
  end
```
