// See the NOTICE file distributed with this work for additional information
// regarding copyright ownership.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import java.io.File

process CHECK_JSON_SCHEMA {
    tag "${json_file.name}"
    label 'default'
    errorStrategy 'finish'

    input:
        tuple val(schema_name), path(json_file)
    
    output:
        tuple val(schema_name), path(json_file)

    script:
        script_dir = workflow.projectDir.toString()
        schema_path = new File(script_dir + "/../../schema", schema_name + "_schema.json")
        """
        check_json_schema --json_file ${json_file} --json_schema ${schema_path}
        """
}