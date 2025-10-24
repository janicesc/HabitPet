import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RequestBody {
  label?: string
  imageBase64?: string
  imageUrl?: string
}

interface NutritionLabel {
  servingSize: string
  caloriesPerServing: number
  totalServings: number
}

interface MenuItem {
  restaurant: string
  itemName: string
  calories: number
}

interface Priors {
  density: { mu: number; sigma: number }
  kcalPerG: { mu: number; sigma: number }
}

interface AnalysisItem {
  label: string
  confidence: number
  calories: number
  sigmaCalories: number
  path: 'label' | 'menu' | 'geometry'
  evidence: string[]
  nutritionLabel?: NutritionLabel
  menuItem?: MenuItem
  priors?: Priors
}

interface Response {
  items: AnalysisItem[]
  meta: {
    used: string[]
    latencyMs: number
  }
}

async function analyzeWithOpenAI(imageData: string, prompt: string): Promise<any> {
  const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiApiKey) {
    throw new Error('OPENAI_API_KEY not configured')
  }

  const requestBody = {
    model: 'gpt-4o',
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'text',
            text: prompt
          },
          {
            type: 'image_url',
            image_url: {
              url: imageData
            }
          }
        ]
      }
    ],
    max_tokens: 1000,
    temperature: 0.1
  }

  console.log('OpenAI request body:', JSON.stringify(requestBody, null, 2))

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(requestBody)
  })

  if (!response.ok) {
    const errorText = await response.text()
    console.error('OpenAI API error response:', errorText)
    throw new Error(`OpenAI API error: ${response.status} ${response.statusText} - ${errorText}`)
  }

  const data = await response.json()
  return data.choices[0].message.content
}

function detectImageType(imageData: string): 'label' | 'menu' | 'geometry' {
  // Simple heuristic-based detection
  // In a real implementation, you might use a more sophisticated approach
  
  // For now, we'll use a simple approach based on the prompt
  // This is a placeholder - in practice, you'd want to analyze the image content
  return 'geometry' // Default to geometry path for home-cooked food
}

async function analyzeLabelPath(imageData: string): Promise<AnalysisItem> {
  const prompt = `Analyze this nutrition label image and extract the following information in JSON format:
  {
    "label": "Product name",
    "servingSize": "Serving size description",
    "caloriesPerServing": number,
    "totalServings": number,
    "confidence": number between 0 and 1
  }
  
  Focus on accuracy and only return valid JSON.`
  
  const result = await analyzeWithOpenAI(imageData, prompt)
  
  try {
    const parsed = JSON.parse(result)
    return {
      label: parsed.label || 'Unknown Product',
      confidence: parsed.confidence || 0.8,
      calories: parsed.caloriesPerServing || 200,
      sigmaCalories: Math.round(parsed.caloriesPerServing * 0.1) || 20,
      path: 'label',
      evidence: ['Analyzer', 'OpenAI', 'Label'],
      nutritionLabel: {
        servingSize: parsed.servingSize || '1 serving',
        caloriesPerServing: parsed.caloriesPerServing || 200,
        totalServings: parsed.totalServings || 1
      }
    }
  } catch (error) {
    // Fallback if JSON parsing fails
    return {
      label: 'Nutrition Label',
      confidence: 0.6,
      calories: 200,
      sigmaCalories: 20,
      path: 'label',
      evidence: ['Analyzer', 'OpenAI', 'Label'],
      nutritionLabel: {
        servingSize: '1 serving',
        caloriesPerServing: 200,
        totalServings: 1
      }
    }
  }
}

async function analyzeMenuPath(imageData: string): Promise<AnalysisItem> {
  const prompt = `Analyze this restaurant food image and identify the menu item. Return JSON format:
  {
    "restaurant": "Restaurant name or type",
    "itemName": "Menu item name",
    "calories": estimated_calories,
    "confidence": number between 0 and 1
  }
  
  Focus on accuracy and only return valid JSON.`
  
  const result = await analyzeWithOpenAI(imageData, prompt)
  
  try {
    const parsed = JSON.parse(result)
    return {
      label: parsed.itemName || 'Restaurant Item',
      confidence: parsed.confidence || 0.7,
      calories: parsed.calories || 500,
      sigmaCalories: Math.round(parsed.calories * 0.15) || 75,
      path: 'menu',
      evidence: ['Analyzer', 'OpenAI', 'Menu'],
      menuItem: {
        restaurant: parsed.restaurant || 'Unknown Restaurant',
        itemName: parsed.itemName || 'Unknown Item',
        calories: parsed.calories || 500
      }
    }
  } catch (error) {
    // Fallback if JSON parsing fails
    return {
      label: 'Restaurant Item',
      confidence: 0.6,
      calories: 500,
      sigmaCalories: 75,
      path: 'menu',
      evidence: ['Analyzer', 'OpenAI', 'Menu'],
      menuItem: {
        restaurant: 'Unknown Restaurant',
        itemName: 'Unknown Item',
        calories: 500
      }
    }
  }
}

async function analyzeGeometryPath(imageData: string): Promise<AnalysisItem> {
  const prompt = `Analyze this food image and estimate calories based on visual density and volume. Return JSON format:
  {
    "label": "Food description",
    "estimatedCalories": number,
    "density": {
      "mu": mean_density_value,
      "sigma": standard_deviation
    },
    "kcalPerG": {
      "mu": mean_calories_per_gram,
      "sigma": standard_deviation
    },
    "confidence": number between 0 and 1
  }
  
  Focus on accuracy and only return valid JSON.`
  
  const result = await analyzeWithOpenAI(imageData, prompt)
  
  try {
    const parsed = JSON.parse(result)
    return {
      label: parsed.label || 'Home-cooked Food',
      confidence: parsed.confidence || 0.6,
      calories: parsed.estimatedCalories || 300,
      sigmaCalories: Math.round(parsed.estimatedCalories * 0.2) || 60,
      path: 'geometry',
      evidence: ['Analyzer', 'OpenAI', 'Geometry'],
      priors: {
        density: parsed.density || { mu: 0.85, sigma: 0.13 },
        kcalPerG: parsed.kcalPerG || { mu: 1.30, sigma: 0.26 }
      }
    }
  } catch (error) {
    // Fallback if JSON parsing fails
    return {
      label: 'Home-cooked Food',
      confidence: 0.5,
      calories: 300,
      sigmaCalories: 60,
      path: 'geometry',
      evidence: ['Analyzer', 'OpenAI', 'Geometry'],
      priors: {
        density: { mu: 0.85, sigma: 0.13 },
        kcalPerG: { mu: 1.30, sigma: 0.26 }
      }
    }
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()

  try {
    const { label, imageBase64, imageUrl }: RequestBody = await req.json()

    if (!imageBase64 && !imageUrl) {
      return new Response(
        JSON.stringify({ error: 'Either imageBase64 or imageUrl is required' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Use imageBase64 if provided, otherwise use imageUrl
    const imageData = imageBase64 || imageUrl!

    // Detect image type to determine analysis path
    const imageType = detectImageType(imageData)
    
    let analysisResult: AnalysisItem

    // Route to appropriate analysis path
    switch (imageType) {
      case 'label':
        analysisResult = await analyzeLabelPath(imageData)
        break
      case 'menu':
        analysisResult = await analyzeMenuPath(imageData)
        break
      case 'geometry':
      default:
        analysisResult = await analyzeGeometryPath(imageData)
        break
    }

    const response: Response = {
      items: [analysisResult],
      meta: {
        used: ['supabase', 'openai'],
        latencyMs: Date.now() - startTime
      }
    }

    return new Response(
      JSON.stringify(response),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error in analyze_food function:', error)
    
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Internal server error',
        meta: {
          used: ['supabase'],
          latencyMs: Date.now() - startTime
        }
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
