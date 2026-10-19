/// Code Snippet / Algorithm Template Model
class CodeSnippet {
  final String id;
  final String title;
  final String category;
  final String description;
  final String code;
  final String? defaultStdin;

  const CodeSnippet({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.code,
    this.defaultStdin,
  });
}

/// Curated B.Tech & Computer Science Algorithm Library
class CodeSnippetsData {
  static final Map<String, List<CodeSnippet>> snippetsByLanguage = {
    'c': [
      CodeSnippet(
        id: 'c_bubble_sort',
        title: 'Bubble Sort Algorithm',
        category: 'Sorting & Arrays',
        description: 'Sorts an integer array in ascending order with step-by-step display',
        code: '''#include <stdio.h>

int main() {
    int arr[] = {64, 34, 25, 12, 22, 11, 90};
    int n = 7;
    
    printf("Original array:\\n");
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\\n\\nSorting steps:\\n");

    for (int i = 0; i < n - 1; i++) {
        for (int j = 0; j < n - i - 1; j++) {
            if (arr[j] > arr[j + 1]) {
                int temp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = temp;
            }
        }
    }

    printf("Sorted array (Ascending):\\n");
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\\n");
    return 0;
}
''',
      ),
      CodeSnippet(
        id: 'c_binary_search',
        title: 'Binary Search Algorithm',
        category: 'Searching',
        description: 'O(log N) search on a sorted integer array',
        code: '''#include <stdio.h>

int main() {
    int arr[] = {2, 5, 8, 12, 16, 23, 38, 56, 72, 91};
    int n = 10;
    int target = 23;
    int low = 0, high = n - 1;
    int foundIndex = -1;

    printf("Searching for %d in sorted array...\\n", target);

    while (low <= high) {
        int mid = (low + high) / 2;
        if (arr[mid] == target) {
            foundIndex = mid;
            break;
        } else if (arr[mid] < target) {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    if (foundIndex != -1) {
        printf("Element %d found at index %d!\\n", target, foundIndex);
    } else {
        printf("Element %d not found in array.\\n", target);
    }
    return 0;
}
''',
      ),
      CodeSnippet(
        id: 'c_fibonacci',
        title: 'Fibonacci Series',
        category: 'Mathematical',
        description: 'Generates the first N Fibonacci numbers',
        code: '''#include <stdio.h>

int main() {
    int n = 10;
    int a = 0, b = 1;
    printf("First %d Fibonacci numbers:\\n", n);
    
    for (int i = 1; i <= n; i++) {
        printf("%d ", a);
        int next = a + b;
        a = b;
        b = next;
    }
    printf("\\n");
    return 0;
}
''',
      ),
      CodeSnippet(
        id: 'c_palindrome',
        title: 'Number Palindrome Check',
        category: 'Number Theory',
        description: 'Checks if an integer reads the same forwards and backwards',
        code: '''#include <stdio.h>

int main() {
    int num = 12321;
    int original = num;
    int reversed = 0;

    while (num > 0) {
        int digit = num % 10;
        reversed = reversed * 10 + digit;
        num = num / 10;
    }

    printf("Original: %d\\n", original);
    printf("Reversed: %d\\n", reversed);
    if (original == reversed) {
        printf("Result: %d is a PALINDROME!\\n", original);
    } else {
        printf("Result: %d is NOT a palindrome.\\n", original);
    }
    return 0;
}
''',
      ),
    ],
    'python': [
      CodeSnippet(
        id: 'py_bubble_sort',
        title: 'Bubble Sort Algorithm',
        category: 'Sorting & Arrays',
        description: 'Classic in-place sorting algorithm in Python',
        code: '''# Bubble Sort Algorithm in Python
def bubble_sort(arr):
    n = len(arr)
    for i in range(n):
        for j in range(0, n - i - 1):
            if arr[j] > arr[j + 1]:
                arr[j], arr[j + 1] = arr[j + 1], arr[j]
    return arr

nums = [64, 34, 25, 12, 22, 11, 90]
print("Original List:", nums)
sorted_nums = bubble_sort(nums)
print("Sorted List:", sorted_nums)
''',
      ),
      CodeSnippet(
        id: 'py_fibonacci_dict',
        title: 'Fibonacci with Dynamic Programming',
        category: 'Algorithms',
        description: 'Memoized Fibonacci sequence generation',
        code: '''# Fibonacci Sequence Generation
def get_fibonacci(n):
    sequence = [0, 1]
    while len(sequence) < n:
        sequence.append(sequence[-1] + sequence[-2])
    return sequence[:n]

n = 10
fib = get_fibonacci(n)
print(f"First {n} Fibonacci numbers: {fib}")
print(f"Sum of first {n} numbers: {sum(fib)}")
''',
      ),
      CodeSnippet(
        id: 'py_prime_checker',
        title: 'Prime Number Generator',
        category: 'Number Theory',
        description: 'Finds all prime numbers up to a specified limit',
        code: '''# Prime Numbers in Range
def find_primes(limit):
    primes = []
    for num in range(2, limit + 1):
        is_prime = True
        for i in range(2, int(num ** 0.5) + 1):
            if num % i == 0:
                is_prime = False
                break
        if is_prime:
            primes.append(num)
    return primes

limit = 50
primes = find_primes(limit)
print(f"Prime numbers up to {limit}:")
print(primes)
print(f"Total count: {len(primes)}")
''',
      ),
      CodeSnippet(
        id: 'py_dict_counter',
        title: 'Word Frequency Counter',
        category: 'Data Structures',
        description: 'Demonstrates Python dictionaries and string processing',
        code: '''# Word Frequency Counter
sentence = "data structures and algorithms data structures in python"
words = sentence.split(" ")
frequency = {}

for w in words:
    frequency[w] = frequency.get(w, 0) + 1

print("Word Frequencies:")
for word, count in frequency.items():
    print(f"- {word}: {count} times")
''',
      ),
    ],
    'cpp': [
      CodeSnippet(
        id: 'cpp_vector_sort',
        title: 'Vector Bubble Sort',
        category: 'STL & Sorting',
        description: 'C++ vector sorting with step-by-step output',
        code: '''#include <iostream>
#include <vector>

int main() {
    std::cout << "C++ Vector Sorting:" << std::endl;
    std::vector<int> v = {45, 12, 85, 32, 89, 39, 69, 44, 42, 1, 45};
    int n = v.size();

    for (int i = 0; i < n - 1; i++) {
        for (int j = 0; j < n - i - 1; j++) {
            if (v[j] > v[j + 1]) {
                int temp = v[j];
                v[j] = v[j + 1];
                v[j + 1] = temp;
            }
        }
    }

    std::cout << "Sorted Vector: ";
    for (int x : v) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    return 0;
}
''',
      ),
      CodeSnippet(
        id: 'cpp_binary_search',
        title: 'Binary Search in C++',
        category: 'Searching',
        description: 'Standard binary search implementation in C++',
        code: '''#include <iostream>
#include <vector>

int main() {
    std::vector<int> arr = {10, 20, 30, 40, 50, 60, 70, 80};
    int target = 50;
    int low = 0, high = arr.size() - 1;
    int index = -1;

    while (low <= high) {
        int mid = (low + high) / 2;
        if (arr[mid] == target) {
            index = mid;
            break;
        } else if (arr[mid] < target) {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    if (index != -1) {
        std::cout << "Target " << target << " found at index " << index << std::endl;
    } else {
        std::cout << "Target not found" << std::endl;
    }
    return 0;
}
''',
      ),
    ],
    'java': [
      CodeSnippet(
        id: 'java_bubble_sort',
        title: 'Bubble Sort in Java',
        category: 'Sorting',
        description: 'Array sorting algorithm in Java',
        code: '''public class Main {
    public static void main(String[] args) {
        int[] arr = {64, 34, 25, 12, 22, 11, 90};
        int n = arr.length;

        System.out.println("Original Array:");
        for (int x : arr) {
            System.out.print(x + " ");
        }
        System.out.println();

        for (int i = 0; i < n - 1; i++) {
            for (int j = 0; j < n - i - 1; j++) {
                if (arr[j] > arr[j + 1]) {
                    int temp = arr[j];
                    arr[j] = arr[j + 1];
                    arr[j + 1] = temp;
                }
            }
        }

        System.out.println("Sorted Array (Ascending):");
        for (int x : arr) {
            System.out.print(x + " ");
        }
        System.out.println();
    }
}
''',
      ),
      CodeSnippet(
        id: 'java_factorial',
        title: 'Factorial Calculator',
        category: 'Mathematical',
        description: 'Iterative factorial with number formatting',
        code: '''public class Main {
    public static void main(String[] args) {
        int n = 7;
        long fact = 1;
        for (int i = 1; i <= n; i++) {
            fact *= i;
        }
        System.out.println("Number: " + n);
        System.out.println("Factorial (" + n + "!) = " + fact);
    }
}
''',
      ),
    ],
    'javascript': [
      CodeSnippet(
        id: 'js_map_filter_reduce',
        title: 'Map, Filter & Reduce',
        category: 'Functional Programming',
        description: 'Modern JavaScript array transformations',
        code: '''// Modern Functional Array Processing
const scores = [65, 88, 92, 45, 78, 99, 54, 82];

// 1. Filter students who passed (>= 60)
const passed = scores.filter(s => s >= 60);
console.log("Passing Scores: " + passed.join(", "));

// 2. Add 5 bonus grace marks
const boosted = passed.map(s => Math.min(100, s + 5));
console.log("Boosted Scores: " + boosted.join(", "));

// 3. Compute class average
const sum = boosted.reduce((acc, curr) => acc + curr, 0);
const avg = (sum / boosted.length).toFixed(2);
console.log("Class Average: " + avg);
''',
      ),
      CodeSnippet(
        id: 'js_palindrome',
        title: 'String Palindrome Checker',
        category: 'Strings',
        description: 'Checks if word is symmetric using string methods',
        code: '''function checkPalindrome(word) {
    const clean = word.toLowerCase();
    const reversed = clean.split("").reverse().join("");
    return clean === reversed;
}

const testWords = ["radar", "hello", "level", "algorithm", "racecar"];
testWords.forEach(w => {
    const isPal = checkPalindrome(w);
    console.log(`Word: "\${w}" -> \${isPal ? "PALINDROME" : "Not Palindrome"}`);
});
''',
      ),
    ],
    'sql': [
      CodeSnippet(
        id: 'sql_crud_grades',
        title: 'Student Grades & Ranking',
        category: 'Table Management',
        description: 'Table creation, insertion, and complex query ordering',
        code: '''-- Create Engineering Grades Table
CREATE TABLE exam_results (
    id INTEGER PRIMARY KEY,
    name TEXT,
    subject TEXT,
    marks INTEGER
);

INSERT INTO exam_results VALUES (1, 'Rohan Gupta', 'Data Structures', 88);
INSERT INTO exam_results VALUES (2, 'Neha Sharma', 'Data Structures', 95);
INSERT INTO exam_results VALUES (3, 'Aman Verma', 'Data Structures', 72);
INSERT INTO exam_results VALUES (4, 'Pooja Patel', 'Operating Systems', 91);
INSERT INTO exam_results VALUES (5, 'Karan Singh', 'Operating Systems', 84);

-- Query Top Performers (Marks >= 85)
SELECT name, subject, marks FROM exam_results WHERE marks >= 85;

-- Calculate Summary
SELECT COUNT(*) as total_students, AVG(marks) as avg_marks FROM exam_results;
''',
      ),
    ],
    'dart': [
      CodeSnippet(
        id: 'dart_list_operations',
        title: 'List Transformation & Statistics',
        category: 'Collections',
        description: 'Dart collection methods and statistics',
        code: '''void main() {
  final marks = [78, 85, 92, 88, 76, 95, 89];
  print('Original Marks: \$marks');

  final total = marks.reduce((a, b) => a + b);
  final average = (total / marks.length).toStringAsFixed(2);
  print('Total Marks: \$total');
  print('Class Average: \$average');

  final topScores = marks.where((m) => m >= 90).toList();
  print('Scores Above 90: \$topScores');
}
''',
      ),
    ],
  };

  /// Returns snippets for a given language, fallback to empty list
  static List<CodeSnippet> getSnippetsForLanguage(String languageKey) {
    return snippetsByLanguage[languageKey] ?? snippetsByLanguage['c'] ?? [];
  }
}
