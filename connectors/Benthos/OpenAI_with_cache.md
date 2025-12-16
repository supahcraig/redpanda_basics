```yaml
http:
  enabled: true
  address: 0.0.0.0:4195
  root_path: /rpcn   # default; keep or change

metrics:
  prometheus: {}



cache_resources:
  - label: tj_mongo_cache
    mongodb:
      url: mongodb://localhost:27017
      database: tjforum
      collection: thread_class_cache
      key_field: _id
      value_field: value

input:
    kafka_franz:
      seed_brokers:
        - seed-6234e08e.curl3eo533cmsnt23dv0.byoc.prd.cloud.redpanda.com:9092
      topics:
        - tjforum.thread_sample

      consumer_group: tj_classification

      tls:
        enabled: true

      sasl:
        - mechanism: SCRAM-SHA-256
          username: cnelson
          password: 


pipeline:
  processors:
    # tally 1 for every input record
    - metric:
        type: counter
        name: tjforum_threads_total
        labels:
          pipeline: tj_classification
        value: 1


    # 0) stash originals in metadata
    - mapping: |
        meta thread_id = this.thread_id.string()
        meta title = this.title
        meta view_url = this.view_url
        meta message = this.message.or("").slice(0, 2000)

        root = this

    # 1) cached OpenAI classification (only runs on cache miss)
    - cached:
        cache: tj_mongo_cache
        key: ${! meta("thread_id") }
        processors:
          - log:
              level: INFO
              message: 'OPENAI CALL (cache miss) thread_id=${! meta("thread_id") } title="${! meta("title") }"'

          # tally 1 for every cache miss
          - metric:
              type: counter
              name: tjforum_openai_calls_total
              labels:
                model: gpt-4o-mini
                pipeline: tj_classification
              value: 1


          - mapping: |
              let cats = [
                "Axles/Differential","Body/Doors/Exterior","Brakes","Cooling","Electrical",
                "Engine / Sensors","Frame","Fuel System","Hard top/Soft top","HVAC","Interior",
                "Lifts/Tires","Lighting","PCM Related","Seats","Sound System","Steering/Suspension",
                "Transfer Case","Transmission","Off-Road / Trail Mods","Odds & Ends"
              ]
              root = {
                "title": meta("title"),
                "message": meta("message"),
                "allowed_categories": $cats
              }

          - openai_chat_completion:
              api_key: ${OPENAI_API_KEY}
              model: gpt-4o-mini
              system_prompt: |
                You classify Jeep Wrangler TJ how-to threads into exactly ONE primary category.
                You MUST choose one from allowed_categories. "Odds & Ends" is acceptable.
              prompt: |
                Title: ${! json("title") }
                Body: ${! json("message") }
                Allowed categories: ${! json("allowed_categories").join(", ") }
                Return JSON only.
              response_format: json_schema
              json_schema:
                name: tj_primary_category
                schema: |
                  {
                    "type":"object",
                    "additionalProperties":false,
                    "properties":{
                      "primary_category":{"type":"string"},
                      "confidence":{"type":"number","minimum":0,"maximum":1},
                      "rationale":{"type":"string"}
                    },
                    "required":["primary_category","confidence","rationale"]
                  }

    # 2) emit unified output
    - mapping: |
        root = {
          "thread_id": meta("thread_id"),
          "title": meta("title"),
          "view_url": meta("view_url"),
          "classification": this
        }


output:
  kafka_franz:
    seed_brokers:
      - seed-6234e08e.curl3eo533cmsnt23dv0.byoc.prd.cloud.redpanda.com:9092

    topic: tjforum.thread_classified
    key: ${! json("thread_id").string() }

    tls:
      enabled: true

    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: 

logger:
  level: INFO
