#!/usr/bin/env python3

# This demonstrates what the proper JSON structure should look like
# based on the actual Hebrew recipe content we parsed

def show_expected_structure():
    """Show what a properly parsed recipe would look like"""
    
    expected_recipe = {
        "recipe": {
            "recipe_name": "אסאדו בתנור",
            "servings": 4,
            "ingredients": [
                {"item": " carne de res", "amount": "1 כוס"},
                {"item": "ירקות חתוכים גס", "amount": "1/3 כוס"}, 
                {"item": "סילאן", "amount": "1/3 כוס"},
                {"item": "מלח גס", "amount": "כפית גדושה"},
                {"item": "פלפל שחור גרוס", "amount": "כפית גדושה"},
                {"item": "מים", "amount": "3/4 כוס"}
            ],
            "steps": [
                {
                    "step_id": "s1",
                    "instruction": "מחממים תנור ל-160 מעלות, מצב חום עליון תחתון רגיל (לא טורבו).",
                    "category": "passive",
                    "duration_minutes": 15,
                    "requirements": {
                        "tools": [" духов"],
                        "heat_source": "oven", 
                        "temp_celsius": 160
                    },
                    "concurrent_friendly": False,
                    "dependencies": []
                },
                {
                    "step_id": "s2",
                    "instruction": "בסיר רחב ושטוח שמתאים לתנור מחממים את שמן הזית.",
                    "category": "active", 
                    "duration_minutes": 5,
                    "requirements": {
                        "tools": ["סיר"],
                        "heat_source": "stovetop",
                        "temp_celsius": None
                    },
                    "concurrent_friendly": False,
                    "dependencies": []
                },
                {
                    "step_id": "s3",
                    "instruction": "מוסיפים את נתחי האסאדו וצורבים מכל הכיוונים 2-4 דקות מכל צד או עד הזהבה יפה.",
                    "category": "active", 
                    "duration_minutes": 10,
                    "requirements": {
                        "tools": ["סיר", "כף"],
                        "heat_source": "stovetop",
                        "temp_celsius": None
                    },
                    "concurrent_friendly": False,
                    "dependencies": []
                }
            ]
        },
        "source_url": "https://www.thekitchencoach.co.il/%D7%90%D7%A1%D7%90%D7%93%D7%95-%D7%91%D7%AA%D7%A0%D7%95%D7%A8/"
    }
    
    import json
    print(json.dumps(expected_recipe, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    show_expected_structure()