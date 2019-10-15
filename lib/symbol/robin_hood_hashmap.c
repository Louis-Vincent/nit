/**
 * This module implements Robin-hood flat hash map.
 * This hash table is based on open addressing which mean every entry are stored
 * inside a contiguous array. By doing so, we avoid (mostly) cache misses that
 * are presents in more traditional hashmap based on bucket linked-list. However,
 * this hashmap doesn't provide pointer stability and delete operation (though it could
 * easily be added).
 *
 * Robin-Hood hashing ensures the layout of the keys stays optimal so successful 
 * and unsuccessful finds are fasts. As a Balanced binary tree, this type of
 * hash map tries to balance the key layout.
 *
 * This kind of hash map are cosidered to be the fastest type of hash map.
 * Finally, to maximize the performance of an Robin-Hood hashmap its better to use
 * a max load factor of 0.5. However, we can (and will) put an higher load factor
 * to avoid wasting too much memory since at 0.75 it is still really fast.
 * 
 * In pratice increasing the load factor affects the stability of the hashmap.
 * In other words, if you have a low load factor (0.5), as you increase the size
 * of your hashtable the performance degrades more smoothly. On the other hands,
 * if your load factor is high (0.9) as you increase the size of your hash table,
 * the performance is less predictable and degrades faster.
 *
 * That being said, benchmarks on the internet has shown 400k keys can be handled
 * really fast with a high load factor which is WAY more than we need for NIT.
 */ 
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <time.h>
#define MAX_LOAD_FACTOR 0.5f
#define IS_BIG_ENDIAN ('\x01\x02\x03\x04' == 0x01020304)

//typedef char byte; 
static long a1 = 0x65d200ce55b19ad8L;
static long b1 = 0x4f2162926e40c299L;
static long c1 = 0x162dd799029970f8L;
static long a2 = 0x68b665e6872bd1f4L;
static long b2 = 0xb6cfcf9d79b51db2L;
static long c2 = 0x7a2b92ae912898c2L;

// 16 bytes on 64-bit system, if the cache line is 64 bytes
// this mean we can query 4 entries per iteration.
// Here I choose to recompute hash for probing distance instead
// of storing the hash in the entry struct for a better use of the cache line.
// Moreover, I don't store hashed key inside another array to avoid cache miss,
// however, this might change.
struct entry {
	void* key;
	void* value;
};

/**
 * Hash table based on open addressing and linear probing.
 * Its capacity must be a power of two, otherwise the hashtable
 * won't work.
 * 
 * This hash table doesn't support deletion, since it will be useless
 * by the system. Moreover, this hashmap doesn't manage the memory of
 * any value that it receives. It's the client job that ensures the 
 * objects are manage by a GC or they live as long as the program runs.
 */ 
struct robin_hood_hmap {
	uint64_t size;		// Current number of element
	uint64_t capacity;	// Must be a power of 2
	uint64_t next_treshold;
	struct entry* entries;	// Array of entry 
};


static inline uint64_t hash(void *key) {
	// hash for 64 bits
	// https://lemire.me/blog/2018/08/15/fast-strongly-universal-64-bit-hashing-everywhere/
	#if UINTPTR_MAX == 0xffffffff
	/* 32-bit */
	return NULL;
	#elif UINTPTR_MAX == 0xffffffffffffffff
	/* 64-bit */
		// TODO: check the endianness
		//#if IS_BIG_ENDIAN
		//uint32_t hi = (uint32_t)key; 
		//uint32_t lo = (uint32_t)((uint64_t)key >> 32);
		//#else
		uint32_t lo = (uint32_t)((void*)key); 
		uint32_t hi = (uint32_t)((uint64_t)key >> 32);
		//#endif
		return ((a1 * lo + b1 * hi + c1) >> 32)
			| ((a2 * lo + b2 * hi + c2) & 0xFFFFFFFF00000000L);
	#else
	/* wtf */
	return NULL;
	#endif
}


// Only works if `n` isa power of two.
static inline uint64_t fast_modulo(uint64_t key, uint64_t n) {
	return key & (n-1);
}

static inline uint64_t probing_distance(uint64_t index, void* key, uint64_t capacity) {
	return fast_modulo(index - fast_modulo(hash(key), capacity), capacity);
}

static void inner_insert(void* key, 
	void* value, 
	struct entry* entries,
	uint64_t my_capacity)
{
	uint64_t hkey = hash(key);
	uint64_t index = fast_modulo(hkey, my_capacity);
	struct entry entry_to_add = { key, value };
	struct entry* current_entry;
	uint64_t prob_distance = 0;
	for(;;) {
		current_entry = &entries[index];
		void* key2 = current_entry->key;
		if(key2 == NULL) {
			// Empty slot, take it!
			break;	
		}
		uint64_t key2_prob_distance = probing_distance(index, key2, my_capacity);
		if(key2_prob_distance < prob_distance) {
			// current_entry is richer, then give to the poor
			struct entry temp = *current_entry;
			*current_entry = entry_to_add;
			entry_to_add = temp;
		}
		prob_distance++;
		index = fast_modulo(index+1, my_capacity);
	}
	// Insert here
	*current_entry = entry_to_add;
}

static struct entry* find_or_null(void *key, struct robin_hood_hmap* hmap, uint64_t* misses) {
	uint64_t hkey = hash(key);
	uint64_t my_capacity = hmap->capacity;
	uint64_t index = fast_modulo(hkey, my_capacity);
	uint64_t prob_distance = 0;
	struct entry* current_entry;
	struct entry* entries = hmap->entries;
	*misses = 0;
	for(;;) {
		current_entry = &entries[index];
		void *key2 = current_entry->key;
		if(key2 == NULL) {
			return NULL;
		}
		if(key2 == key) {
			break;
		}
		uint64_t key2_prob_distance = probing_distance(index, key2, my_capacity);
		if(key2_prob_distance < prob_distance) {
			return NULL;
		}
		prob_distance++;
		index = fast_modulo(index+1, my_capacity);
		*misses = *misses + 1;
	}
	return current_entry;
}

static void rehash(struct robin_hood_hmap* hmap) {
	struct entry* new_entries = calloc(hmap->capacity, sizeof(struct entry));
	uint64_t size = hmap->capacity / 2;	
	struct entry* old_entry = hmap->entries;
	for(uint64_t i=0; i < size; i++, old_entry++) {
		if(old_entry->key != NULL) {
			inner_insert(old_entry->key, 
				old_entry->value, 
				new_entries, 
				hmap->capacity);
		}
	}

	// Free and replace the entries array
	free(hmap->entries);
	hmap->entries = new_entries;
}


/**
 * Inserts a new key-value entry into the hash table `hmap`.
 */ 
void robin_hood_hmap_insert(void* key, void* value, struct robin_hood_hmap* hmap) {
	uint64_t size = hmap->size;
	uint64_t my_capacity = hmap->capacity;
	//printf("current_load: %lu, next_treshold: %lu\n", size, hmap->next_treshold);
	if(size >= hmap->next_treshold) {
		my_capacity *= 2;
		hmap->capacity = my_capacity;
		rehash(hmap);
		hmap->next_treshold = my_capacity * MAX_LOAD_FACTOR;
	}
	inner_insert(key, value, hmap->entries, my_capacity);
	hmap->size++;
}

void* robin_hood_hmap_find(void *key, struct robin_hood_hmap* hmap) {
	uint64_t misses;
	struct entry* e = find_or_null(key, hmap, &misses);
	if (e == NULL) {
		return NULL;
	} else {
		if(misses > 2) {
			printf("misses: %lu\n", misses);
		}
		return e->value;
	}
}


struct robin_hood_hmap* init_robin_hood_hmap(uint64_t capacity, void* never_key) {
	struct entry* entries = calloc(capacity, sizeof(struct entry));
	struct robin_hood_hmap* hmap = malloc(sizeof(struct robin_hood_hmap));
	hmap->entries = entries;
	hmap->size = 0;
	hmap->capacity = capacity;
	hmap->next_treshold = capacity * MAX_LOAD_FACTOR;
	return hmap;
}

void delete_robin_hood_hmap(struct robin_hood_hmap* hmap) {
	free(hmap->entries);
	free(hmap);
}

typedef struct ref_long {
	long x;
} RefLong;

void randomize ( RefLong** arr, size_t n )
{ 
    // Use a different seed value so that we don't get same 
    // result each time we run this program 
    srand ( time(NULL) ); 
  
    // Start from the last element and swap one by one. We don't 
    // need to run for the first element that's why i > 0 
    for (int i = n-1; i > 0; i--) 
    { 
        // Pick a random index from 0 to i 
        int j = rand() % (i+1); 
  
        // Swap arr[i] with the element at random index 
	RefLong* temp = arr[i]; 
	arr[i] = arr[j];
	arr[j] = temp;
    } 
} 
int main(void) {
	struct robin_hood_hmap* hmap = init_robin_hood_hmap(2048, NULL);
	RefLong** xs = malloc(sizeof(RefLong)*1000000);
	RefLong** ys = malloc(sizeof(RefLong)*1000000);
	for(long i = 0; i < 1000000; ++i) {
		//printf("inserting: %lu\n", i);
		RefLong* rl = malloc(sizeof(RefLong));
		rl->x = i;
		xs[i] = rl;
		ys[i] = rl;
		//robin_hood_hmap_insert(rl, (void*)i, hmap);
	}

	randomize(ys, 1000000);
	for(long i = 0; i < 1000000; ++i) {
		robin_hood_hmap_insert(ys[i], (void*)i, hmap);
	}
	clock_t start,end;
	double cpu_time_used;
	for(long i = 0; i < 1000000; ++i) {
		void* key = xs[i];
		start = clock();
		long res = (long)robin_hood_hmap_find(key, hmap);
		int good = ys[res] == key;
		end = clock();
		cpu_time_used = ((double) (end - start)) / CLOCKS_PER_SEC;
		printf("(%lu, %lu), time taken: %lf, good?: %d\n", i, res, cpu_time_used, good);	
	}
	return 0;
}
