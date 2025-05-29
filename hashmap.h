
#define INITIAL_SIZE (256)
#define MAX_CHAIN_LENGTH (8)

//Elements of the hashmap
typedef struct hashmap_element{
	char* key;
	int in_use;
	int type;
} hashmap_element;

//The hashmap itself
typedef struct hashmap_map{
	int table_size;
	int size;
	hashmap_element *data;
} hashmap_map;

hashmap_map* hashmap_new();
int set(hashmap_map* in, char* key, int type);
int get(hashmap_map* m, char* key);
void hashmap_free(hashmap_map* in);
int hashmap_length(hashmap_map* in);
unsigned int hashmap_hash_int(hashmap_map * m, char* keystring);
unsigned long crc32(const unsigned char *s, unsigned int len);
int hashmap_hash(hashmap_map* m, char* key);
int hashmap_rehash(hashmap_map* m);
